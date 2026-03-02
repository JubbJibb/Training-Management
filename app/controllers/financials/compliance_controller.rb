# frozen_string_literal: true

module Financials
  class ComplianceController < Financials::BaseController
    def index
      @checklist = Financials::ComplianceChecklistQuery.call(filter_params)
      @issues = Financials::ComplianceIssuesQuery.call(filter_params)
      @severity_counts = @issues.group_by { |i| i[:severity] }.transform_values(&:count)
    end

    private

    def filter_params
      params.permit(:period, :date_from, :date_to, :client_type, :status, :missing_only, :overdue_only, :corporate_only).to_h.symbolize_keys
    end
  end
end
