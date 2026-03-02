# frozen_string_literal: true

module Insights
  class BusinessController < Insights::BaseController
    def index
      @data = safe_business_data
      @date_range = @data[:date_range] || {}
      @filter_params = filter_params.merge(
        start_date: params[:start_date].presence || @date_range[:start_date],
        end_date: params[:end_date].presence || @date_range[:end_date],
        compare_to_previous: params[:compare_to_previous],
        trend_by: params[:trend_by].presence || @data[:trend_by].presence
      )
      @courses_for_filter = Course.order(:title).pluck(:title, :id)
    end

    private

    def safe_business_data
      Insights::BusinessInsightsQuery.new(query_params).call
    rescue StandardError => e
      Rails.logger.warn("BusinessInsightsQuery error: #{e.message}")
      {
        summary: {},
        funnel_data: [],
        channel_mix_data: [],
        trend_data: [],
        cohort_heatmap_data: { row_labels: [], col_labels: [], cells: [] },
        top_channels: [],
        top_courses: [],
        top_spenders: [],
        repeat_learners: [],
        date_range: { preset: "last_30d", start_date: 30.days.ago.to_date, end_date: Date.current },
        compare_to_previous_period: true,
        previous_period: nil,
        executive_summary: { text: "" },
        kpis: [],
        revenue_trend_series: [],
        best_selling_courses: { by_revenue: [], by_paid: [], by_cvr: [] },
        pricing_insights: { avg_price_trend: [], distribution: [] },
        channel_performance: { sort_by: "revenue", rows: [] },
        returning_revenue_pct: 0,
        margin_na_reason: nil
      }
    end

    def query_params
      {
        preset: params[:preset].presence || "last_30d",
        start_date: params[:start_date],
        end_date: params[:end_date],
        course_id: params[:course_id],
        channel: params[:channel],
        compare_to_previous: params[:compare_to_previous],
        trend_by: params[:trend_by]
      }
    end

    def filter_params
      {
        preset: params[:preset].presence || "last_30d",
        start_date: params[:start_date],
        end_date: params[:end_date],
        course_id: params[:course_id].presence || "",
        channel: params[:channel].presence || "all",
        compare_to_previous: params[:compare_to_previous],
        trend_by: params[:trend_by].presence || ""
      }
    end
  end
end
