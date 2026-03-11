# frozen_string_literal: true

class CreateBudgetAllocations < ActiveRecord::Migration[8.0]
  def change
    create_table :budget_allocations do |t|
      t.references :budget_year, null: false, foreign_key: true
      t.references :budget_category, null: false, foreign_key: true
      t.decimal :allocated_amount, precision: 14, scale: 2, null: false, default: 0
      t.json :monthly_plan

      t.timestamps
    end
    add_index :budget_allocations, [:budget_year_id, :budget_category_id], unique: true, name: "index_budget_allocations_on_year_and_category"
  end
end
