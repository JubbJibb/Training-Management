# frozen_string_literal: true

module Financials
  class DateRangeResolver
    PRESETS = { "mtd" => :mtd, "qtd" => :qtd, "ytd" => :ytd, "custom" => :custom }.freeze

    def initialize(params = {})
      @params = params.is_a?(Hash) ? params : {}
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
      @params[:period].to_s.downcase.presence || "mtd"
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
        from = parse_date(@params[:date_from]) || Date.current.beginning_of_month
        to = parse_date(@params[:date_to]) || Date.current.end_of_month
        from..to
      else
        Date.current.beginning_of_month..Date.current.end_of_month
      end
    rescue ArgumentError
      Date.current.beginning_of_month..Date.current.end_of_month
    end

    def parse_date(val)
      return nil if val.blank?
      Date.parse(val.to_s)
    end
  end
end
