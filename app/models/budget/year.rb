# frozen_string_literal: true

module Budget
  class Year < ApplicationRecord
    self.table_name = "budget_years"

    STATUSES = %w[draft active closed].freeze

    has_many :budget_allocations, class_name: "Budget::Allocation", foreign_key: :budget_year_id, dependent: :destroy
    has_many :budget_expenses, class_name: "Budget::Expense", foreign_key: :budget_year_id, dependent: :restrict_with_error
    has_many :budget_categories, through: :budget_allocations

    validates :year, presence: true, uniqueness: true, numericality: { only_integer: true }
    validates :status, presence: true, inclusion: { in: STATUSES }
    validates :total_budget, numericality: { greater_than_or_equal_to: 0 }

    scope :by_year, -> { order(year: :desc) }
    scope :active, -> { where(status: "active") }
    scope :draft, -> { where(status: "draft") }
    scope :closed, -> { where(status: "closed") }

    def self.current
      active.find_by(year: Date.current.year) || by_year.first
    end
  end
end
