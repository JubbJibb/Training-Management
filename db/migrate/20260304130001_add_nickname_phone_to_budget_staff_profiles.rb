# frozen_string_literal: true

class AddNicknamePhoneToBudgetStaffProfiles < ActiveRecord::Migration[8.1]
  def change
    add_column :budget_staff_profiles, :nickname, :string
    add_column :budget_staff_profiles, :phone, :string
  end
end
