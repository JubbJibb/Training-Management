# frozen_string_literal: true

module Budget
  class Category < ApplicationRecord
    self.table_name = "budget_categories"

    COST_TYPES = %w[fixed variable].freeze

    has_many :budget_allocations, class_name: "Budget::Allocation", foreign_key: :budget_category_id, dependent: :destroy
    has_many :budget_expenses, class_name: "Budget::Expense", foreign_key: :budget_category_id, dependent: :nullify

    validates :name, presence: true
    validates :code, presence: true, uniqueness: true
    validates :cost_type, presence: true, inclusion: { in: COST_TYPES }
    validates :sort_order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

    scope :ordered, -> { order(sort_order: :asc, name: :asc) }
  end
end
