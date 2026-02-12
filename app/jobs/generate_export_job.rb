# frozen_string_literal: true

class GenerateExportJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(export_job_id)
    job = ExportJob.find_by(id: export_job_id)
    return unless job&.queued?

    job.mark_running!
    generator = build_generator(job)
    generator.call(job)
  rescue StandardError => e
    Rails.logger.error("[GenerateExportJob] export_job_id=#{export_job_id} error=#{e.message}")
    job&.mark_failed!(e.message)
    raise
  end

  private

  def build_generator(job)
    filters = job.filters_hash.symbolize_keys
    sections = job.include_sections_hash.symbolize_keys
    include_custom = job.include_custom_fields

    case [job.export_type, job.format]
    when ["financial_report", "pdf"] then Exports::FinancialReportPdf.new(filters: filters, include_sections: sections, include_custom_fields: include_custom)
    when ["class_report", "pdf"] then Exports::ClassReportPdf.new(filters: filters, include_sections: sections, include_custom_fields: include_custom)
    when ["customer_summary", "pdf"] then Exports::CustomerSummaryPdf.new(filters: filters, include_sections: sections, include_custom_fields: include_custom)
    when ["financial_data", "xlsx"] then Exports::FinancialDataXlsx.new(filters: filters, include_sections: sections, include_custom_fields: include_custom)
    when ["class_attendees", "xlsx"] then Exports::ClassAttendeesXlsx.new(filters: filters, include_sections: sections, include_custom_fields: include_custom)
    when ["customer_master", "xlsx"] then Exports::CustomerMasterXlsx.new(filters: filters, include_sections: sections, include_custom_fields: include_custom)
    when ["customer_for_accounting", "xlsx"] then Exports::CustomerForAccountingXlsx.new(filters: filters, include_sections: sections, include_custom_fields: include_custom)
    else
      raise ArgumentError, "Unsupported export: #{job.export_type} / #{job.format}"
    end
  end
end
