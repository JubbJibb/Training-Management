class Attendee < ApplicationRecord
  belongs_to :training_class
  belongs_to :customer, optional: true
  
  has_many :attendee_promotions, dependent: :destroy
  has_many :promotions, through: :attendee_promotions
  
  has_one_attached :payment_slip
  
  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :email, uniqueness: { scope: :training_class_id, message: "has already been registered for this class" }
  validates :participant_type, inclusion: { in: %w[Indi Corp] }
  validates :payment_status, inclusion: { in: %w[Pending Paid] }, allow_nil: true
  validates :document_status, inclusion: { in: %w[QT INV Receipt] }, allow_nil: true
  validates :attendance_status, inclusion: { in: %w[มาเรียน No-show] }, allow_nil: true
  validates :status, inclusion: { in: %w[attendee potential] }, allow_nil: true
  validate :payment_slip_content_type, if: -> { payment_slip.attached? }
  validate :payment_slip_size, if: -> { payment_slip.attached? }

  before_validation :normalize_email
  after_save :ensure_customer_link
  
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
  
  private

  def normalize_email
    self.email = email.to_s.strip.downcase
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
  
  def payment_slip_content_type
    allowed_types = ['image/png', 'image/jpeg', 'image/jpg', 'image/gif', 'application/pdf']
    unless allowed_types.include?(payment_slip.content_type)
      errors.add(:payment_slip, 'must be an image (PNG, JPG, GIF) or PDF')
    end
  end
  
  def payment_slip_size
    if payment_slip.byte_size > 10.megabytes
      errors.add(:payment_slip, 'must be less than 10MB')
    end
  end
  
  scope :corp, -> { where(participant_type: "Corp") }
  scope :indi, -> { where(participant_type: "Indi") }
  scope :paid, -> { where(payment_status: "Paid") }
  scope :attended, -> { where(attendance_status: "มาเรียน") }
  scope :attendees, -> { where("status = ? OR status IS NULL OR status = ''", "attendee") }
  scope :potential_customers, -> { where(status: "potential") }
end

