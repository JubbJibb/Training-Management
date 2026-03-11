# frozen_string_literal: true

module Budget
  class StaffWorklogsController < Budget::BaseController
    def create
      @worklog = Budget::StaffWorklog.new(worklog_params)
      if @worklog.save
        redirect_to budget_staff_worklogs_path(year: @worklog.work_date.year, month: @worklog.work_date.month), notice: "Worklog added."
      else
        redirect_to budget_staff_worklogs_path, alert: @worklog.errors.full_messages.to_sentence
      end
    end

    def destroy
      @worklog = Budget::StaffWorklog.find(params[:id])
      year, month = @worklog.work_date.year, @worklog.work_date.month
      @worklog.destroy
      redirect_to budget_staff_worklogs_path(year: year, month: month), notice: "Worklog removed."
    end

    private

    def worklog_params
      params.require(:budget_staff_worklog).permit(:staff_profile_id, :work_date, :mandays, :linked_type, :linked_id, :notes)
    end
  end
end
