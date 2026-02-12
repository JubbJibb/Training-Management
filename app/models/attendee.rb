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
  
  def base_price
    # ใช้ราคาจาก TrainingClass (ราคาตั้งต้นต่อหัว) เป็นค่าเริ่มต้นเสมอ
    training_class.price.to_f || 0
  end
  
  def calculate_final_price
    base = base_price
    return (base * 1.07).round(2) if promotions.where(active: true).empty?
    
    final_price = base
    promotions.where(active: true).each do |promotion|
      discount = promotion.calculate_discount(base)
      final_price -= discount
    end
    final_price = [final_price, 0].max # ไม่ให้ราคาติดลบ
    (final_price * 1.07).round(2) # รวม VAT 7% และปัดเป็นทศนิยม 2 ตำแหน่ง
  end
  
  def calculate_price_before_vat
    base = base_price
    return base.round(2) if promotions.where(active: true).empty?
    
    final_price = base
    promotions.where(active: true).each do |promotion|
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
    return 0.0 if promotions.where(active: true).empty?
    
    promotions.where(active: true).sum { |promotion| promotion.calculate_discount(base) }.round(2)
  end

  # For QT/INV/Receipt: Billing Name = company (Corp) or name_thai/name (Indi)
  def document_billing_name
    if participant_type == "Corp"
      company.presence || name_thai.presence || name.presence
    else
      name_thai.presence || name.presence
    end
  end

  # Total price for this registration (Amount shown in UI). Stored in total_amount for SUM(Total Spend).
  def total_final_price
    calculate_final_price * (seats || 1)
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
  def ensure_customer_link
    return if email.blank?
    return if customer_id.present?

    c = Customer.find_or_initialize_by(email: email)
    c.name = name if c.name.blank?
    c.phone = phone if c.phone.blank?
    c.participant_type = participant_type if c.participant_type.blank?
    c.company = company if c.company.blank?
    # Default "Company Name" for documents for corporate customers
    if participant_type == "Corp" && c.billing_name.blank? && company.present?
      c.billing_name = company
    end
    c.save! if c.new_record? || c.changed?

    update_column(:customer_id, c.id)
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
    if address.present? && c.billing_address != address
      c.billing_address = address
      changed = true
    end
    name_value = name_thai.presence || name.presence
    if name_value.present? && c.name != name_value
      c.name = name_value
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
  
  scope :corp, -> { where(participant_type: "Corp") }
  scope :indi, -> { where(participant_type: "Indi") }
  scope :paid, -> { where(payment_status: "Paid") }
  scope :attended, -> { where(attendance_status: "มาเรียน") }
  scope :attendees, -> { where("status = ? OR status IS NULL OR status = ''", "attendee") }
  scope :potential_customers, -> { where(status: "potential") }
end

