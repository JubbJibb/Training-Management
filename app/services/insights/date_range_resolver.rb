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

    def filter_params
      { preset: preset, start_date: start_date, end_date: end_date }
    end

    private

    def build_range
      case preset
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
