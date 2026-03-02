# frozen_string_literal: true

module Financials
  # Returns trend rows (label, revenue, costs, profit, margin) by month or week for the selected period.
  # Respects filter_params; basis (accrual/cash) affects revenue (accrual = booked paid, cash = collected in period).
  class OverviewTrendQuery
    class << self
      def call(params = {})
        new(params).call
      end
    end

    def initialize(params = {})
      @params = params
      @resolver = Financials::DateRangeResolver.new(params)
      @basis = (params[:basis].to_s.presence || "accrual").downcase
    end

    def call
      range = @resolver.start_date..@resolver.end_date
      months = range.map { |d| d.beginning_of_month }.uniq
      if months.size <= 12
        months.map { |month_start| row_for_month(month_start) }
      else
        weeks = range.to_a.each_slice(7).map(&:first).uniq.first(24)
        weeks.map { |week_start| row_for_week(week_start) }
      end
    end

    private

    def row_for_month(month_start)
      month_end = month_start.end_of_month
      end_date = [month_end, @resolver.end_date].min
      range = month_start..end_date
      rev = revenue_in_range(range)
      cost = costs_in_range(range)
      profit = rev - cost
      margin = rev.positive? ? ((profit / rev) * 100).round(1) : 0
      {
        label: month_start.strftime("%b %Y"),
        revenue: rev,
        costs: cost,
        profit: profit,
        margin: margin
      }
    end

    def revenue_in_range(range)
      scope = Attendee.attendees.joins(:training_class)
        .where(training_classes: { date: range })
      scope = scope.where(participant_type: @params[:client_type]) if @params[:client_type].in?(%w[Indi Corp])
      scope = scope.where(payment_status: @params[:status]) if @params[:status].in?(%w[Pending Paid])
      if @basis == "cash"
        scope.where(payment_status: "Paid").sum { |a| (a.total_final_price || 0) }
      else
        scope.sum { |a| (a.total_final_price || 0) }
      end
    end

    def costs_in_range(range)
      instructor = TrainingClass.where(date: range).sum(:cost).to_f
      expenses = ClassExpense.joins(:training_class).where(training_classes: { date: range }).sum(:amount).to_f
      instructor + expenses
    end

    def row_for_week(week_start)
      range = week_start..([week_start + 6.days, @resolver.end_date].min)
      rev = revenue_in_range(range)
      cost = costs_in_range(range)
      profit = rev - cost
      margin = rev.positive? ? ((profit / rev) * 100).round(1) : 0
      {
        label: "#{week_start.strftime('%d/%m')}–#{range.end.strftime('%d/%m')}",
        revenue: rev,
        costs: cost,
        profit: profit,
        margin: margin
      }
    end
  end
end
