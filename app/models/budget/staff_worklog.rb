# frozen_string_literal: true

module Budget
  class StaffWorklog < ApplicationRecord
    self.table_name = "budget_staff_worklogs"

    belongs_to :staff_profile, class_name: "Budget::StaffProfile", foreign_key: :staff_profile_id
    belongs_to :linked, polymorphic: true, optional: true

    validates :work_date, presence: true
    validates :mandays, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 5 }

    scope :in_year_month, ->(year, month) {
      start_date = Date.new(year.to_i, month.to_i, 1)
      end_date = start_date.end_of_month
      where(work_date: start_date..end_date)
    }
  end
end