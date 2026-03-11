class AddEndDateToBudgetStaffProfiles < ActiveRecord::Migration[8.1]
  def change
    add_column :budget_staff_profiles, :end_date, :date
  end
end
