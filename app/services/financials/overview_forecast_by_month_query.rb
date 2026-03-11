# frozen_string_literal: true

module Financials
  # Returns forecast revenue by month for the selected period.
  # Forecast = Capacity × Price/seat ของแต่ละ Class แล้ว sum ต่อเดือน
  # ใช้ max_attendees เป็น Capacity, price เป็น Price ต่อที่นั่ง
  class OverviewForecastByMonthQuery
    class << self
      def call(params = {})
        new(params).call
      end
    end

    def initialize(params = {})
      @params = params
      @resolver = Financials::DateRangeResolver.new(params)
    end

    def call
      @period_range = @resolver.start_date..@resolver.end_date
      range_for_months = @period_range
      # YTD: แสดง forecast รายเดือนทั้งปี (12 เดือน)
      if @resolver.preset == "ytd"
        year = @resolver.start_date.year
        range_for_months = Date.new(year, 1, 1)..Date.new(year, 12, 31)
      end
      months = range_for_months.map { |d| d.beginning_of_month }.uniq
      months.map { |month_start| row_for_month(month_start) }
    end

    private

    def row_for_month(month_start)
      month_end = month_start.end_of_month
      if @resolver.preset == "ytd"
        range = month_start..month_end
      else
        effective_start = [month_start, @period_range.begin].max
        effective_end = [month_end, @period_range.end].min
        range = effective_start <= effective_end ? effective_start..effective_end : nil
      end
      forecast = range ? forecast_revenue_in_range(range) : 0.0
      {
        label: month_start.strftime("%b %Y"),
        month_start: month_start,
        forecast_revenue: forecast
      }
    end

    # แต่ละ Class: Capacity × Price/seat แล้ว sum
    def forecast_revenue_in_range(range)
      classes = TrainingClass.where(date: range)
      classes.sum do |tc|
        capacity = (tc.max_attendees.presence || 0).to_i
        price_per_seat = tc.price.to_f
        (capacity * price_per_seat).round(2)
      end
    end
  end
end
