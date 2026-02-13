class Attendee < ApplicationRecord
  belongs_to :training_class
  belongs_to :customer, optional: true
  
  has_many :attendee_promotions, dependent: :destroy
  has_many :promotions, through: :attendee_promotions
  
  has_many_attached :payment_slips

  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :email, uniqueness: { scope: :training_class_id, message: "has already been registered for this class" }
  validates :participant_type, inclusion: { in: %w[Indi Corp] }
  validates :seats, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :payment_status, inclusion: { in: %w[Pending Paid] }, allow_nil: true
  validates :document_status, inclusion: { in: %w[QT INV Receipt] }, allow_nil: true
  validates :attendance_status, inclusion: { in: %w[มาเรียน No-show] }, allow_nil: true
  validates :status, inclusion: { in: %w[attendee potential] }, allow_nil: true
  validate :payment_slips_content_type
  validate :payment_slips_size

  before_validation :normalize_email
  before_validation :set_seats_for_indi
  after_save :ensure_customer_link
  after_save :sync_tax_info_to_customer
  after_save :update_total_amount
  after_save :set_payment_date_from_slips

  # วันที่ชำระเงินจากสลิป (ใช้วันที่อัปโหลดสลิปที่เก่าที่สุด)
  def payment_date_from_slips
    return nil unless payment_slips.attached?
    first = payment_slips.min_by { |b| b.created_at || Time.current }
    first&.created_at&.to_date
  end

  # แสดงวันที่ชำระเงิน: ใช้ payment_date ถ้ามี ไม่เช่นนั้นใช้จากสลิป
  def display_payment_date
    payment_date.presence || payment_date_from_slips
  end

  def base_price
    # ใช้ราคาจาก TrainingClass (ราคาตั้งต้นต่อหัว) เป็นค่าเริ่มต้นเสมอ
    training_class.price.to_f || 0
  end

  # Use loaded promotions when present to avoid N+1 (e.g. Finance dashboard)
  def active_promotions
    promotions.loaded? ? promotions.select(&:active?) : promotions.where(active: true)
  end
  
  def calculate_final_price
    base = base_price
    return (base * 1.07).round(2) if active_promotions.empty?
    
    final_price = base
    active_promotions.each do |promotion|
      discount = promotion.calculate_discount(base)
      final_price -= discount
    end
    final_price = [final_price, 0].max # ไม่ให้ราคาติดลบ
    (final_price * 1.07).round(2) # รวม VAT 7% และปัดเป็นทศนิยม 2 ตำแหน่ง
  end
  
  def calculate_price_before_vat
    base = base_price
    return base.round(2) if active_promotions.empty?
    
    final_price = base
    active_promotions.each do |promotion|
      discount = promotion.calculate_discount(base)
      final_price -= discount
    end
    [final_price, 0].max.round(2) # ไม่ให้ราคาติดลบ และปัดเป็นทศนิยม 2 ตำแหน่ง
  end
  
  def calculate_vat_amount
    (calculate_price_before_vat * 0.07).round(2)
  end
  
  def total_discount_amount
    base = base_price
    return 0.0 if active_promotions.empty?
    
    active_promotions.sum { |promotion| promotion.calculate_discount(base) }.round(2)
  end

  # For QT/INV/Receipt: prefer stored billing_name, else company/name_thai/name
  def document_billing_name
    return billing_name.presence if respond_to?(:billing_name) && billing_name.present?
    if participant_type == "Corp"
      company.presence || name_thai.presence || name.presence
    else
      name_thai.presence || name.presence
    end
  end

  # Document address: prefer stored billing_address, else address
  def document_billing_address
    return billing_address.presence if respond_to?(:billing_address) && billing_address.present?
    address.presence
  end

  # Billing & Tax (QT/INV/Receipt) completeness – same 3 fields as Customer for icon display
  def billing_tax_status
    {
      tax_id: tax_id.present?,
      billing_name: document_billing_name.present?,
      billing_address: document_billing_address.present?
    }
  end

  def billing_tax_present_values_short
    tax_short = if tax_id.present?
      tax_id.length >= 9 ? "#{tax_id[0, 4]}…#{tax_id[-4, 4]}" : tax_id
    end
    addr = document_billing_address
    addr_short = addr.present? ? (addr.length > 40 ? "#{addr[0, 40]}…" : addr) : nil
    {
      tax_id: tax_short,
      billing_name: document_billing_name.presence,
      billing_address: addr_short
    }
  end

  # Sync from linked customer: attendee.tax_id = customer.tax_id, billing_name = customer.name_thai, billing_address = customer.address
  def sync_document_info_from_customer
    return unless customer_id.present?
    c = customer
    self.tax_id = c.tax_id.presence || tax_id
    if self.class.column_names.include?("billing_name")
      self.billing_name = c.respond_to?(:name_thai) && c.name_thai.present? ? c.name_thai : (c.billing_name.presence || billing_name)
    end
    if self.class.column_names.include?("billing_address")
      self.billing_address = (c.respond_to?(:address) && c.address.present? ? c.address : c.billing_address).presence || billing_address
    end
  end

  # Total price for this registration (Amount shown in UI). Stored in total_amount for SUM(Total Spend).
  # ปัด 2 ตำแหน่งให้ตรงกับ total_amount ที่เก็บใน DB
  def total_final_price
    (calculate_final_price * (seats || 1)).round(2)
  end

  # Gross sales (full price before discount) for this registration. base_price × seats.
  def gross_sales_amount
    base_price * (seats || 1)
  end

  def total_price_before_vat
    calculate_price_before_vat * (seats || 1)
  end

  def total_vat_amount
    calculate_vat_amount * (seats || 1)
  end
  
  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end

  def set_seats_for_indi
    self.seats = 1 if participant_type == "Indi"
  end

  # Link attendee -> customer by email. Only fills blank customer fields (won't override).
  # After linking, sync attendee.tax_id / billing_name / billing_address from customer.
  def ensure_customer_link
    return if email.blank?
    return if customer_id.present?

    c = Customer.find_or_initialize_by(email: email)
    c.name = name if c.name.blank?
    c.phone = phone if c.phone.blank?
    c.participant_type = participant_type if c.participant_type.blank?
    c.company = company if c.company.blank?
    if participant_type == "Corp" && c.billing_name.blank? && company.present?
      c.billing_name = company
    end
    c.save! if c.new_record? || c.changed?

    update_column(:customer_id, c.id)

    # New link: copy from customer to attendee (tax_id, billing_name = name_thai, billing_address = address)
    sync_document_info_from_customer
    attrs = {}
    attrs[:tax_id] = tax_id if self.class.column_names.include?("tax_id")
    attrs[:billing_name] = billing_name if self.class.column_names.include?("billing_name")
    attrs[:billing_address] = billing_address if self.class.column_names.include?("billing_address")
    update_columns(attrs) if attrs.any?
  end

  # Sync ข้อมูลออกเอกสาร (Tax ID, Billing Name, Billing Address) จาก Attendee ไปที่ Customer Profile
  def sync_tax_info_to_customer
    return unless customer_id.present?

    c = customer
    changed = false
    if tax_id.present? && c.tax_id != tax_id
      c.tax_id = tax_id
      changed = true
    end
    addr = document_billing_address
    if addr.present? && c.billing_address != addr
      c.billing_address = addr
      changed = true
    end
    if c.respond_to?(:address=) && addr.present? && c.address != addr
      c.address = addr
      changed = true
    end
    name_value = name_thai.presence || name.presence
    if name_value.present? && c.name != name_value
      c.name = name_value
      changed = true
    end
    if c.respond_to?(:name_thai=) && name_thai.present? && c.name_thai != name_thai
      c.name_thai = name_thai
      changed = true
    end
    billing = document_billing_name
    if billing.present? && c.billing_name != billing
      c.billing_name = billing
      changed = true
    end
    c.save! if changed
  end

  def update_total_amount
    return unless self.class.column_names.include?("total_amount")
    amt = (calculate_final_price * (seats || 1)).round(2)
    update_column(:total_amount, amt) if read_attribute(:total_amount).to_d != amt
  end

  def payment_slips_content_type
    allowed_types = ['image/png', 'image/jpeg', 'image/jpg', 'image/gif', 'application/pdf']
    payment_slips.each do |slip|
      unless allowed_types.include?(slip.content_type)
        errors.add(:payment_slips, 'must be images (PNG, JPG, GIF) or PDF')
        break
      end
    end
  end

  def payment_slips_size
    payment_slips.each do |slip|
      if slip.byte_size > 10.megabytes
        errors.add(:payment_slips, 'each file must be less than 10MB')
        break
      end
    end
  end

  def set_payment_date_from_slips
    return unless payment_slips.attached?
    return if payment_date.present?
    date_from_slip = payment_date_from_slips
    return if date_from_slip.blank?
    update_column(:payment_date, date_from_slip)
  end

  scope :corp, -> { where(participant_type: "Corp") }
  scope :indi, -> { where(participant_type: "Indi") }
  scope :paid, -> { where(payment_status: "Paid") }
  scope :attended, -> { where(attendance_status: "มาเรียน") }
  scope :attendees, -> { where("status = ? OR status IS NULL OR status = ''", "attendee") }
  scope :potential_customers, -> { where(status: "potential") }
end

