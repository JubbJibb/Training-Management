# frozen_string_literal: true

module Staff
  class Forecast
    def self.rows(year, month)
      new.rows(year, month)
    end

    def self.totals(year, month)
      new.totals(year, month)
    end

    def self.previous_month_totals(year, month)
      prev = Date.new(year.to_i, month.to_i, 1) - 1.month
      new.totals(prev.year, prev.month)
    end

    def rows(year, month)
      y, m = year.to_i, month.to_i
      m = [[m, 1].max, 12].min
      staff = Budget::StaffProfile.active.by_name
      plans_by_key = Budget::StaffMonthlyPlan.for_month(y, m).includes(:staff_profile).index_by(&:staff_profile_id)
      staff.map do |profile|
        plan = plans_by_key[profile.id] || Budget::StaffMonthlyPlan.new(staff_profile_id: profile.id, year: y, month: m, status: "planned")
        planned = plan.planned_days.to_f
        cost = (planned * profile.internal_day_rate.to_f).round(2)
        { staff_profile: profile, plan: plan, planned_days: planned, estimated_cost: cost }
      end.sort_by { |r| -r[:estimated_cost] }
    end

    def totals(year, month)
      r = rows(year, month)
      total_days = r.sum { |x| x[:planned_days] }.round(2)
      total_cost = r.sum { |x| x[:estimated_cost] }.round(2)
      staff_count = r.size
      { staff_count: staff_count, total_planned_days: total_days, total_estimated_cost: total_cost }
    end
  end
end
