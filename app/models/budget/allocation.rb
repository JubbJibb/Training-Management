# frozen_string_literal: true

module Budget
  class Allocation < ApplicationRecord
    self.table_name = "budget_allocations"

    belongs_to :budget_year, class_name: "Budget::Year", foreign_key: :budget_year_id
    belongs_to :budget_category, class_name: "Budget::Category", foreign_key: :budget_category_id

    validates :allocated_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :budget_category_id, uniqueness: { scope: :budget_year_id }

    scope :for_year, ->(year) { where(budget_year_id: year.id) }
  end
end
