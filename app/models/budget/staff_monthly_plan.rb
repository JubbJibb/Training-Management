# frozen_string_literal: true

module Budget
  class StaffMonthlyPlan < ApplicationRecord
    self.table_name = "budget_staff_monthly_plans"

    STATUSES = %w[planned locked].freeze

    belongs_to :staff_profile, class_name: "Budget::StaffProfile", foreign_key: :staff_profile_id

    validates :year, presence: true, numericality: { only_integer: true }
    validates :month, presence: true, numericality: { only_integer: true }, inclusion: { in: 1..12 }
    validates :status, presence: true, inclusion: { in: STATUSES }
    validates :planned_days, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 31 }, allow_nil: true
    validates :staff_profile_id, uniqueness: { scope: [:year, :month] }

    scope :for_month, ->(year, month) { where(year: year, month: month) }
    scope :locked, -> { where(status: "locked") }

    def estimated_cost
      return 0 if planned_days.blank?
      (planned_days.to_f * staff_profile.internal_day_rate.to_f).round(2)
    end

    def locked?
      status == "locked"
    end
  end
end
