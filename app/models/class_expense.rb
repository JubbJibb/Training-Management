class ClassExpense < ApplicationRecord
  belongs_to :training_class

  # สถานะการจ่าย: paid = จ่ายแล้ว, deposit = มัดจำ, unpaid = ยังไม่จ่าย
  PAYMENT_STATUSES = [
    ["ยังไม่จ่าย", "unpaid"],
    ["มัดจำ", "deposit"],
    ["จ่ายแล้ว", "paid"]
  ].freeze

  validates :description, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :payment_status, inclusion: { in: %w[unpaid deposit paid] }, allow_nil: true

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
