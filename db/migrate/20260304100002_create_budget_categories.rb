# frozen_string_literal: true

class CreateBudgetCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :budget_categories do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.integer :sort_order, default: 0
      t.string :cost_type, null: false, default: "variable"

      t.timestamps
    end
    add_index :budget_categories, :code, unique: true
    add_index :budget_categories, :sort_order
  end
end
