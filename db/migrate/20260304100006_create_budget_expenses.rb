# frozen_string_literal: true

class CreateBudgetExpenses < ActiveRecord::Migration[8.0]
  def change
    create_table :budget_expenses do |t|
      t.references :budget_year, null: false, foreign_key: true
      t.references :budget_category, null: false, foreign_key: true
      t.decimal :amount, precision: 14, scale: 2, null: false
      t.date :expense_date, null: false
      t.string :vendor
      t.string :reference_no
      t.string :payment_status, null: false, default: "planned"
      t.string :payment_method
      t.text :notes
      t.bigint :class_id
      t.bigint :campaign_id
      t.references :sponsorship_deal, null: true, foreign_key: true

      t.timestamps
    end
    add_index :budget_expenses, [:budget_year_id, :expense_date]
    add_index :budget_expenses, [:budget_year_id, :budget_category_id]
    add_index :budget_expenses, [:budget_year_id, :payment_status]
    add_index :budget_expenses, :expense_date
  end
end
