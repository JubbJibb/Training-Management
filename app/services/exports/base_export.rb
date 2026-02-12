# frozen_string_literal: true

module Exports
  class BaseExport
    COMPANY = {
      name: "บริษัท ออด-อี (ประเทศไทย) จำกัด",
      address: "สำนักงานใหญ่ 2549/41-43 พหลโยธิน ลาดยาว จตุจักร กรุงเทพ 10900",
      email: "th@odd-e.com",
      phone: "020110684",
      tax_id: "0-1055-56110-71-8"
    }.freeze

    def initialize(filters: {}, include_sections: {}, include_custom_fields: false)
      @filters = filters
      @include_sections = include_sections
      @include_custom_fields = include_custom_fields
    end

    def call(export_job)
      filename = suggested_filename
      io = build_io
      export_job.mark_succeeded!(filename: filename, io: io)
    rescue StandardError => e
      export_job.mark_failed!(e.message)
      raise
    end

    protected

    attr_reader :filters, :include_sections, :include_custom_fields

    def date_range
      start_date = filters[:start_date].presence && Date.parse(filters[:start_date].to_s)
      end_date = filters[:end_date].presence && Date.parse(filters[:end_date].to_s)
      period = filters[:period].to_s
      start_date ||= case period
                     when "last_month" then Date.current.last_month.beginning_of_month
                     when "ytd" then Date.current.beginning_of_year
                     else Date.current.beginning_of_month
                     end
      end_date ||= case period
                   when "last_month" then Date.current.last_month.end_of_month
                   when "ytd" then Date.current
                   else Date.current.end_of_month
                   end
      start_date..end_date
    end

    def scope_attendees
      range = date_range
      scope = Attendee.attendees.joins(:training_class).where("training_classes.date >= ? AND training_classes.date <= ?", range.begin, range.end)
      scope = scope.where(training_class_id: filters[:course_id]) if filters[:course_id].present?
      scope = scope.where(participant_type: filters[:segment]) if filters[:segment].present? && %w[Indi Corp].include?(filters[:segment].to_s)
      scope = scope.where(payment_status: filters[:status]) if filters[:status].present? && %w[Paid Pending].include?(filters[:status].to_s)
      scope = scope.where(source_channel: filters[:channel]) if filters[:channel].present?
      scope
    end

    def suggested_filename
      "#{export_type_slug}-#{Date.current.iso8601}.bin"
    end

    def export_type_slug
      "export"
    end

    def build_io
      raise NotImplementedError
    end
  end
end
