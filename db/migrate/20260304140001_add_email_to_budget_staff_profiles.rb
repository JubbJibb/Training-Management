# frozen_string_literal: true

class AddEmailToBudgetStaffProfiles < ActiveRecord::Migration[8.1]
  def change
    add_column :budget_staff_profiles, :email, :string
  end
end
