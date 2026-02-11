class Promotion < ApplicationRecord
  has_many :attendee_promotions, dependent: :destroy
  has_many :attendees, through: :attendee_promotions
  
  validates :name, presence: true
  validates :discount_type, presence: true, inclusion: { in: %w[percentage fixed buy_x_get_y] }
  validates :discount_value, presence: true, numericality: { greater_than: 0 }
  validates :base_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  
  scope :active, -> { where(active: true) }
  
  def calculate_discount(original_price)
    discount = case discount_type
    when 'percentage'
      original_price * (discount_value / 100.0)
    when 'fixed'
      discount_value
    when 'buy_x_get_y'
      # สำหรับ "มา 4 จ่าย 3" discount_value = 3 (จ่าย 3 คน)
      # ส่วนลด "ต่อหัว" = original_price / (discount_value + 1)
      # เช่น ราคา 1000, discount_value = 3 => ส่วนลด = 1000 / 4 = 250 (จ่ายสุทธิ 750)
      original_price / (discount_value + 1)
    else
      0
    end
    discount.round(2) # ปัดเป็นทศนิยม 2 ตำแหน่ง
  end
  
  def display_name
    "#{name} (#{discount_description})"
  end
  
  def discount_description
    case discount_type
    when 'percentage'
      "ลด #{discount_value}%"
    when 'fixed'
      "ลด #{discount_value} บาท"
    when 'buy_x_get_y'
      "มา #{discount_value + 1} จ่าย #{discount_value}"
    else
      name
    end
  end
end
