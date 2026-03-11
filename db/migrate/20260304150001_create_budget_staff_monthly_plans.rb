# frozen_string_literal: true

class CreateBudgetStaffMonthlyPlans < ActiveRecord::Migration[8.1]
  def change
    create_table :budget_staff_monthly_plans do |t|
      t.references :staff_profile, null: false, foreign_key: { to_table: :budget_staff_profiles }
      t.integer :year, null: false
      t.integer :month, null: false
      t.decimal :planned_days, precision: 6, scale: 2
      t.text :notes
      t.string :status, default: "planned", null: false

      t.timestamps
    end
    add_index :budget_staff_monthly_plans, [:staff_profile_id, :year, :month], unique: true, name: "index_staff_monthly_plans_on_profile_year_month"
    add_index :budget_staff_monthly_plans, [:year, :month]
  end
end
