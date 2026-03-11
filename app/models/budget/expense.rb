# frozen_string_literal: true

module Budget
  class Expense < ApplicationRecord
    self.table_name = "budget_expenses"

    PAYMENT_STATUSES = %w[planned committed paid].freeze

    belongs_to :budget_year, class_name: "Budget::Year", foreign_key: :budget_year_id
    belongs_to :budget_category, class_name: "Budget::Category", foreign_key: :budget_category_id, optional: true
    belongs_to :sponsorship_deal, class_name: "SponsorshipDeal", optional: true

    validates :amount, presence: true, numericality: { greater_than: 0 }
    validates :expense_date, presence: true
    validates :payment_status, presence: true, inclusion: { in: PAYMENT_STATUSES }

    scope :paid, -> { where(payment_status: "paid") }
    scope :committed, -> { where(payment_status: "committed") }
    scope :planned, -> { where(payment_status: "planned") }
    scope :in_month, ->(year, month) { where(budget_year_id: year.id).where("strftime('%m', expense_date) = ?", month.to_s.rjust(2, "0")) }
    scope :in_date_range, ->(start_date, end_date) { where(expense_date: start_date..end_date) }
  end
end
