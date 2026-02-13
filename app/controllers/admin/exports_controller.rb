# frozen_string_literal: true

module Admin
  class ExportsController < ApplicationController
    layout "admin"
    before_action :set_export_job, only: [:show]

    def index
      @export_jobs = policy_scope(ExportJob).limit(50)
    end

    def new
      export_type = params[:export_type].presence || "financial_report"
      format = params[:file_format].presence || default_format_for(export_type)
      @export_job = ExportJob.new(export_type: export_type, format: format)
      @filter_training_classes = TrainingClass.order(date: :desc).limit(80)
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
        filters: [:start_date, :end_date, :course_id, :segment, :status, :channel, :period, :breakdown, :purpose, :payment_status, { class_ids: [] }, { columns: [] }],
        include_sections: [:promotion_breakdown, :ar_aging, :attendee_list]
      )
      {
        export_type: p[:export_type],
        format: p[:format],
        include_custom_fields: p[:include_custom_fields],
        filters: build_filters_hash(p[:filters]),
        include_sections: build_include_sections_hash(p[:include_sections])
      }
    end

    def build_filters_hash(filters_param)
      return {} if filters_param.blank?
      h = {}
      %i[start_date end_date course_id segment status channel period breakdown purpose payment_status].each do |k|
        h[k] = filters_param[k].presence
      end
      h[:class_ids] = Array(filters_param[:class_ids]).reject(&:blank?) if filters_param.key?(:class_ids)
      h[:columns] = Array(filters_param[:columns]).reject(&:blank?) if filters_param.key?(:columns)
      h.compact
    end

    def build_include_sections_hash(sections_param)
      return {} if sections_param.blank?
      %i[promotion_breakdown ar_aging attendee_list].each_with_object({}) do |k, h|
        h[k] = sections_param[k] if sections_param[k].present?
      end
    end

    def default_format_for(export_type)
      ExportJob::EXPORT_TYPES.include?(export_type) && %w[overall_revenue_summary class_financial_report attendee_master_editable pending_receipt attendee_complete].include?(export_type) ? "xlsx" : "pdf"
    end
  end
end
