# frozen_string_literal: true

module Budget
  class StaffMonthlyPlansController < Budget::BaseController
    def create
      @plan = Budget::StaffMonthlyPlan.new(plan_params)
      if @plan.save
        render_row_response
      else
        head :unprocessable_entity
      end
    end

    def update
      @plan = Budget::StaffMonthlyPlan.find(params[:id])
      if @plan.update(plan_params)
        render_row_response
      else
        head :unprocessable_entity
      end
    end

    private

    def plan_params
      params.require(:budget_staff_monthly_plan).permit(:staff_profile_id, :year, :month, :planned_days, :notes, :status)
    end

    def render_row_response
      row_data = { staff_profile: @plan.staff_profile, plan: @plan, planned_days: @plan.planned_days.to_f, estimated_cost: @plan.estimated_cost }
      target_id = @plan.previously_new_record? ? "forecast_row_#{@plan.staff_profile_id}" : dom_id(@plan, :forecast_row)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(target_id, partial: "budget/staff/forecast_row", locals: { row_data: row_data, year: @plan.year, month: @plan.month, month_locked: @plan.locked? }), status: :ok
        end
        format.html { redirect_to budget_staff_forecast_path(year: @plan.year, month: @plan.month), notice: "Saved." }
      end
    end
  end
end
