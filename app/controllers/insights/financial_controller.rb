# frozen_string_literal: true

module Insights
  class FinancialController < Insights::BaseController
    def index
      @data = safe_financial_data
      @date_range = @data[:date_range] || {}
      @filter_params = filter_params
    end

    private

    def safe_financial_data
      Insights::FinancialInsights.new(date_params).call
    rescue StandardError
      {
        kpis: {},
        chart_data: { cash_in_vs_out: [], ar_aging: [] },
        overdue_invoices: [],
        date_range: { preset: "mtd", start_date: Date.current.beginning_of_month, end_date: Date.current }
      }
    end

    def date_params
      { preset: params[:preset], start_date: params[:start_date], end_date: params[:end_date] }
    end

    def filter_params
      {
        preset: params[:preset].presence || "mtd",
        start_date: params[:start_date],
        end_date: params[:end_date],
        client_type: params[:client_type].presence || "all",
        channel: params[:channel].presence || "all",
        min_revenue: params[:min_revenue],
        overdue_only: params[:overdue_only],
        outstanding_only: params[:outstanding_only]
      }
    end
  end
end
