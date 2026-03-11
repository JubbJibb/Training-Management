# frozen_string_literal: true

class CreateBudgetStaffProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :budget_staff_profiles do |t|
      t.string :name, null: false
      t.string :role
      t.string :department
      t.decimal :internal_day_rate, precision: 14, scale: 2, default: 0, null: false
      t.string :status, default: "active", null: false
      t.date :effective_from

      t.timestamps
    end
    add_index :budget_staff_profiles, :status
    add_index :budget_staff_profiles, [:department, :status]
  end
end
