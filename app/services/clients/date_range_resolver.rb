# frozen_string_literal: true

module Clients
  # Reuse same logic as Insights for MTD/YTD/Custom.
  class DateRangeResolver
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

    private

    def build_range
      case preset
      when "mtd"
        Date.current.beginning_of_month..Date.current.end_of_month
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
