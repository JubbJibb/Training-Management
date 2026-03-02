# frozen_string_literal: true

module Financials
  class ExpensesByClassQuery
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
      scope = ClassExpense.joins(:training_class)
        .where(training_classes: { date: @resolver.start_date..@resolver.end_date })
      scope.includes(:training_class).order("training_classes.date DESC").group_by(&:training_class_id).map do |tc_id, expenses|
        tc = expenses.first.training_class
        expense_total = expenses.sum(&:amount)
        revenue = tc.attendees.attendees.where(payment_status: "Paid").sum { |a| (a.total_final_price || 0) }
        {
          training_class_id: tc_id,
          title: tc.title,
          date: tc.date,
          expense_total: expense_total,
          revenue: revenue,
          profit: (revenue - expense_total).round(2),
          expenses: expenses
        }
      end.sort_by { |h| -(h[:date] || Date.current).to_time.to_i }
    end
  end
end
