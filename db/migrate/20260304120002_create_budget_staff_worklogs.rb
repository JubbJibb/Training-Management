# frozen_string_literal: true

class CreateBudgetStaffWorklogs < ActiveRecord::Migration[8.1]
  def change
    create_table :budget_staff_worklogs do |t|
      t.references :staff_profile, null: false, foreign_key: { to_table: :budget_staff_profiles }
      t.date :work_date, null: false
      t.decimal :mandays, precision: 4, scale: 2, default: 1.0, null: false
      t.string :linked_type
      t.bigint :linked_id
      t.text :notes

      t.timestamps
    end
    add_index :budget_staff_worklogs, [:staff_profile_id, :work_date]
    add_index :budget_staff_worklogs, :work_date
    add_index :budget_staff_worklogs, [:linked_type, :linked_id]
  end
end
