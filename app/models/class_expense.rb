class ClassExpense < ApplicationRecord
  belongs_to :training_class
  
  validates :description, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  
  # Categories
  CATEGORIES = [
    "ค่าขนม",
    "ค่าอาหาร",
    "เครื่องดื่ม",
    "อุปกรณ์",
    "ค่าเช่าสถานที่",
    "ค่าเดินทาง",
    "อื่นๆ"
  ].freeze
end
