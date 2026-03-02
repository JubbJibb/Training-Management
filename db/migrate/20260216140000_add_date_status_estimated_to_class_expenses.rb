# frozen_string_literal: true

class AddDateStatusEstimatedToClassExpenses < ActiveRecord::Migration[7.0]
  def change
    add_column :class_expenses, :expense_date, :date
    add_column :class_expenses, :payment_status, :string, default: "unpaid"
    add_column :class_expenses, :is_estimated, :boolean, default: false, null: false
  end
end
