# frozen_string_literal: true

module Budget
  class StaffController < Budget::BaseController
    def index
      @q = params[:q].to_s.strip
      @staff_profiles = Budget::StaffProfile.by_name
      if @q.present?
        q = "%#{Budget::StaffProfile.sanitize_sql_like(@q)}%"
        @staff_profiles = @staff_profiles.where(
          "name LIKE :q OR nickname LIKE :q OR email LIKE :q OR department LIKE :q OR role LIKE :q OR phone LIKE :q",
          q: q
        )
      end
      @active_count = Budget::StaffProfile.active.count
      @inactive_count = Budget::StaffProfile.where(status: "inactive").count
    end

    def forecast
      @year = (params[:year].presence || Date.current.year).to_i
      @month = (params[:month].presence || Date.current.month).to_i
      @month = [[@month, 1].max, 12].min
      @forecast_rows = Staff::Forecast.rows(@year, @month)
      @totals = Staff::Forecast.totals(@year, @month)
      @prev_totals = Staff::Forecast.previous_month_totals(@year, @month)
      @month_locked = Budget::StaffMonthlyPlan.for_month(@year, @month).locked.exists?
    end

    def worklogs
      @year = (params[:year].presence || Date.current.year).to_i
      @month = (params[:month].presence || Date.current.month).to_i
      @month = [[@month, 1].max, 12].min
      @staff_profiles = Budget::StaffProfile.active.by_name
      @monthly_cost = Staff::Cost.monthly_cost(@year, @month)
      @distribution = Staff::Cost.distribution(@year, @month)
      @worklogs = Budget::StaffWorklog.in_year_month(@year, @month).includes(:staff_profile).order(work_date: :desc)
      @worklog = Budget::StaffWorklog.new(work_date: Date.new(@year, @month, 1))
    end

    def copy_previous_month
      year = (params[:year].presence || Date.current.year).to_i
      month = (params[:month].presence || Date.current.month).to_i
      month = [[month, 1].max, 12].min
      prev = Date.new(year, month, 1) - 1.month
      prev_plans = Budget::StaffMonthlyPlan.for_month(prev.year, prev.month).includes(:staff_profile)
      prev_plans.each do |prev_plan|
        plan = Budget::StaffMonthlyPlan.find_or_initialize_by(staff_profile_id: prev_plan.staff_profile_id, year: year, month: month)
        next if plan.locked?
        plan.planned_days = prev_plan.planned_days
        plan.notes = prev_plan.notes
        plan.status = "planned"
        plan.save!
      end
      redirect_to budget_staff_forecast_path(year: year, month: month), notice: "Copied plans from #{prev.strftime('%B %Y')}."
    end

    def set_default_days
      year = (params[:year].presence || Date.current.year).to_i
      month = (params[:month].presence || Date.current.month).to_i
      month = [[month, 1].max, 12].min
      default_days = (params[:default_days].presence || 20).to_f
      staff_ids = params[:staff_ids].to_s.split(",").map(&:strip).reject(&:blank?)
      scope = Budget::StaffProfile.active.by_name
      scope = scope.where(id: staff_ids) if staff_ids.any?
      scope.find_each do |profile|
        plan = Budget::StaffMonthlyPlan.find_or_initialize_by(staff_profile_id: profile.id, year: year, month: month)
        next if plan.locked?
        plan.planned_days = default_days
        plan.status = "planned"
        plan.save!
      end
      redirect_to budget_staff_forecast_path(year: year, month: month), notice: "Set default days to #{default_days} for selected staff."
    end

    def lock_month
      year = (params[:year].presence || Date.current.year).to_i
      month = (params[:month].presence || Date.current.month).to_i
      month = [[month, 1].max, 12].min
      Budget::StaffMonthlyPlan.for_month(year, month).update_all(status: "locked")
      redirect_to budget_staff_forecast_path(year: year, month: month), notice: "Month locked."
    end
  end
end
