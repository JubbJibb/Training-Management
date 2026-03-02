# frozen_string_literal: true

module Financials
  class ExpenseCategoryTotalsQuery
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
      ClassExpense.joins(:training_class)
        .where(training_classes: { date: @resolver.start_date..@resolver.end_date })
        .group(:category)
        .sum(:amount)
        .map { |cat, total| { category: cat.presence || "Uncategorized", total: total } }
        .sort_by { |h| -h[:total] }
    end
  end
end
