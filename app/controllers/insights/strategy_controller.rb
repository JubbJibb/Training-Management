# frozen_string_literal: true

module Insights
  class StrategyController < Insights::BaseController
    def index
      @data = safe_strategy_data
      @date_range = @data[:date_range] || {}
      @filter_params = filter_params
    end

    private

    def safe_strategy_data
      Insights::StrategyInsights.new(date_params).call
    rescue StandardError
      {
        kpis: {},
        chart_data: {},
        promotion_leaderboard: [],
        underperforming_promotions: [],
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
        low_fill_threshold: params[:low_fill_threshold].presence || "40",
        inactive_days: params[:inactive_days].presence || "90"
      }
    end
  end
end
