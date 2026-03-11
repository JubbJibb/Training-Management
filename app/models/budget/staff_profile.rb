# frozen_string_literal: true

module Budget
  class StaffProfile < ApplicationRecord
    self.table_name = "budget_staff_profiles"

    STATUSES = %w[active inactive].freeze

    has_many :staff_worklogs, class_name: "Budget::StaffWorklog", foreign_key: :staff_profile_id, dependent: :destroy
    has_many :staff_monthly_plans, class_name: "Budget::StaffMonthlyPlan", foreign_key: :staff_profile_id, dependent: :destroy

    validates :name, presence: true
    validates :nickname, length: { maximum: 50 }, allow_blank: true
    validates :phone, format: { with: /\A[\d\s\-+]+\z/, message: "only allows digits, spaces, + and -" }, allow_blank: true
    validates :email, format: { with: URI::MailTo::EMAIL_REGEXP, message: "is not a valid email" }, allow_blank: true
    validates :internal_day_rate, numericality: { greater_than_or_equal_to: 0 }
    validates :status, presence: true, inclusion: { in: STATUSES }
    validate :end_date_after_start_date, if: -> { effective_from.present? && end_date.present? }

    scope :active, -> { where(status: "active") }
    scope :by_name, -> { order(:name) }

    private

    def end_date_after_start_date
      return if end_date >= effective_from
      errors.add(:end_date, "must be on or after start date")
    end
  end
end
