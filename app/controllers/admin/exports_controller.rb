# frozen_string_literal: true

module Admin
  class ExportsController < ApplicationController
    layout "admin"
    before_action :set_export_job, only: [:show]

    def index
      @export_jobs = policy_scope(ExportJob).limit(50)
    end

    def new
      # Use file_format to avoid Rails treating it as request format (e.g. .pdf / .xlsx)
      @export_job = ExportJob.new(export_type: params[:export_type], format: params[:file_format])
      authorize @export_job
    end

    def create
      @export_job = ExportJob.new(export_job_params)
      @export_job.requested_by_id = current_user&.id
      authorize @export_job

      if @export_job.save
        GenerateExportJob.perform_later(@export_job.id)
        redirect_to admin_exports_path, notice: "Export queued."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def show
      authorize @export_job
      if @export_job.succeeded? && @export_job.file.attached?
        redirect_to rails_blob_path(@export_job.file), allow_other_host: false
      else
        redirect_to admin_exports_path, alert: "Export not ready or failed."
      end
    end

    private

    def set_export_job
      @export_job = ExportJob.find(params[:id])
    end

    def export_job_params
      p = params.require(:export_job).permit(
        :export_type, :format, :include_custom_fields,
        filters: [:start_date, :end_date, :course_id, :segment, :status, :channel, :period],
        include_sections: [:promotion_breakdown, :ar_aging, :attendee_list]
      )
      p[:filters] = (p[:filters] || {}).compact_blank
      p[:include_sections] = (p[:include_sections] || {}).compact_blank
      p
    end
  end
end
