class Attendee < ApplicationRecord
  belongs_to :training_class
  
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
  validate :payment_slip_content_type, if: -> { payment_slip.attached? }
  validate :payment_slip_size, if: -> { payment_slip.attached? }
  
  def calculate_final_price
    base_price = self.price || training_class.price || 0
    return base_price if promotions.where(active: true).empty?
    
    final_price = base_price
    promotions.where(active: true).each do |promotion|
      discount = promotion.calculate_discount(base_price)
      final_price -= discount
    end
    [final_price, 0].max # ไม่ให้ราคาติดลบ
  end
  
  def total_discount_amount
    base_price = self.price || training_class.price || 0
    return 0 if promotions.where(active: true).empty?
    
    promotions.where(active: true).sum { |promotion| promotion.calculate_discount(base_price) }
  end
  
  private
  
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
end

