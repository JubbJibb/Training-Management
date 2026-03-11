# frozen_string_literal: true

class CreateBudgetYears < ActiveRecord::Migration[8.0]
  def change
    create_table :budget_years do |t|
      t.integer :year, null: false
      t.decimal :total_budget, precision: 14, scale: 2, default: 0
      t.string :status, null: false, default: "draft"
      t.string :owner_name
      t.text :notes

      t.timestamps
    end
    add_index :budget_years, :year, unique: true
    add_index :budget_years, :status
  end
end
