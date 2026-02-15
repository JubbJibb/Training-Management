# frozen_string_literal: true

module Insights
  # Operational performance: revenue, profit, fill rate, repeat rate, programs, upcoming classes.
  # Returns kpis, chart_data (revenue_by_program, revenue_trend), top_programs table, alerts (low enrollment).
  class BusinessInsights
    CACHE_TTL = 5.minutes
    LOW_ENROLLMENT_THRESHOLD = 0.30 # 30% fill rate

    def initialize(params = {})
      @resolver = DateRangeResolver.new(params)
      @params = params
    end

    def call
      Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
        {
          kpis: kpis,
          chart_data: {
            revenue_by_program: revenue_by_program,
            revenue_trend: revenue_trend
          },
          top_programs: top_programs,
          alerts: alerts
        }
      end.merge(date_range: { start_date: @resolver.start_date, end_date: @resolver.end_date, preset: @resolver.preset })
    end

    private

    def cache_key
      ["insights/business", @resolver.start_date, @resolver.end_date].join("/")
    end

    def range
      @resolver.range
    end

    def attendees_scope
      @attendees_scope ||= Attendee.attendees
        .joins(:training_class)
        .where("training_classes.date >= ? AND training_classes.date <= ?", range.begin, range.end)
        .includes(:training_class, :customer)
    end

    def attendees
      @attendees ||= attendees_scope.to_a
    end

    def classes_in_range
      @classes_in_range ||= TrainingClass.where(date: range).includes(:attendees)
    end

    def kpis
      total_revenue = attendees.sum(&:total_final_price).round(2)
      total_net = attendees.sum(&:total_price_before_vat).round(2)
      class_ids = attendees.map(&:training_class_id).uniq
      total_cost = class_ids.sum { |id| TrainingClass.find_by(id: id)&.total_cost.to_f }.round(2)
      total_profit = (total_net - total_cost).round(2)

      # Fill rate: weighted average by seats per class
      fill_rates = classes_in_range.filter_map { |tc| tc.fill_rate_percent && tc.max_attendees.to_i.positive? ? [tc.fill_rate_percent, tc.max_attendees] : nil }
      avg_fill = fill_rates.any? ? (fill_rates.sum { |r, cap| r * cap }.to_f / fill_rates.sum { |_, cap| cap }).round(1) : nil

      # Repeat client rate: customers with >1 attendee (in period or ever)
      customer_ids = attendees.map(&:customer_id).compact.uniq
      repeat_count = customer_ids.count { |cid| Attendee.attendees.where(customer_id: cid).count > 1 }
      repeat_rate = customer_ids.any? ? ((repeat_count.to_f / customer_ids.size) * 100).round(1) : 0

      upcoming_scope = TrainingClass.where("date >= ? AND date <= ?", Date.current, 30.days.from_now.to_date)
      upcoming_count = upcoming_scope.count

      {
        total_revenue: total_revenue,
        total_profit: total_profit,
        fill_rate: avg_fill,
        repeat_client_rate: repeat_rate,
        active_programs: TrainingClass.where(date: range).count,
        upcoming_classes: upcoming_count
      }
    end

    def revenue_by_program
      attendees.group_by(&:training_class).map do |tc, list|
        { label: tc.title, value: list.sum(&:total_final_price).round(2) }
      end.sort_by { |h| -h[:value] }.first(12)
    end

    def revenue_trend
      by_month = attendees.group_by { |a| a.training_class.date&.beginning_of_month }.compact
      by_month.transform_values! { |list| list.sum(&:total_final_price).round(2) }
      (range.begin.to_date.beginning_of_month..range.end.to_date.end_of_month).select { |d| d == d.beginning_of_month }.map do |month|
        { label: month.strftime("%b %Y"), value: by_month[month] || 0 }
      end
    end

    def top_programs
      breakdown = classes_in_range.map do |tc|
        list = attendees.select { |a| a.training_class_id == tc.id }
        rev = list.sum(&:total_final_price).round(2)
        net = list.sum(&:total_price_before_vat).round(2)
        cost = tc.total_cost
        profit = (net - cost).round(2)
        fill = tc.fill_rate_percent
        { id: tc.id, title: tc.title, date: tc.date, revenue: rev, profit: profit, fill_rate: fill, seats_sold: list.size }
      end
      breakdown.sort_by { |h| -h[:revenue] }.first(5)
    end

    def alerts
      low = TrainingClass.where("date >= ? AND date <= ?", Date.current, 30.days.from_now.to_date)
        .select { |tc| tc.max_attendees.to_i.positive? && (tc.fill_rate_percent || 0) < (LOW_ENROLLMENT_THRESHOLD * 100) }
        .map { |tc| { id: tc.id, title: tc.title, date: tc.date, fill_rate: tc.fill_rate_percent, max_attendees: tc.max_attendees } }
      { low_enrollment_upcoming: low }
    end
  end
end
