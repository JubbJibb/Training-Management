# frozen_string_literal: true

module Insights
  # Resolves MTD / YTD / Custom date range from params for Insights pages.
  class DateRangeResolver
    PRESETS = { "mtd" => :mtd, "qtd" => :qtd, "ytd" => :ytd, "custom" => :custom }.freeze

    def initialize(params = {})
      @params = params
    end

    def range
      @range ||= build_range
    end

    def start_date
      range.begin
    end

    def end_date
      range.end
    end

    def preset
      @params[:preset].to_s.downcase
    end

    # Previous period: same-length window immediately before start_date
    def previous_period_range
      return nil if range.nil? || range.begin.nil?
      len = (range.end.to_date - range.begin.to_date).to_i + 1
      prev_end = range.begin.to_date - 1
      prev_start = prev_end - len + 1
      prev_start..prev_end
    end

    def previous_start_date
      previous_period_range&.begin
    end

    def previous_end_date
      previous_period_range&.end
    end

    def filter_params
      { preset: preset, start_date: start_date, end_date: end_date }
    end

    private

    def build_range
      case preset
      when "last_7d"
        7.days.ago.to_date..Date.current
      when "last_30d"
        30.days.ago.to_date..Date.current
      when "last_90d"
        90.days.ago.to_date..Date.current
      when "mtd"
        Date.current.beginning_of_month..Date.current.end_of_month
      when "qtd"
        Date.current.beginning_of_quarter..Date.current.end_of_quarter
      when "ytd"
        Date.current.beginning_of_year..Date.current
      when "custom"
        from = @params[:start_date].present? ? Date.parse(@params[:start_date].to_s) : Date.current.beginning_of_month
        to = @params[:end_date].present? ? Date.parse(@params[:end_date].to_s) : Date.current.end_of_month
        from..to
      else
        Date.current.beginning_of_month..Date.current.end_of_month
      end
    rescue ArgumentError
      Date.current.beginning_of_month..Date.current.end_of_month
    end
  end
end
