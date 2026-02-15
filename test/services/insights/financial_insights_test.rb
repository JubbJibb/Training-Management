# frozen_string_literal: true

require "test_helper"

module Insights
  class FinancialInsightsTest < ActiveSupport::TestCase
    test "call returns expected keys" do
      result = Insights::FinancialInsights.new(preset: "mtd").call
      assert result.key?(:kpis)
      assert result.key?(:chart_data)
      assert result.key?(:overdue_invoices)
      assert result.key?(:expense_by_category)
      assert result.key?(:date_range)
      assert result[:kpis].key?(:booked_revenue)
      assert result[:kpis].key?(:collected_revenue)
      assert result[:chart_data].key?(:cash_in_vs_out)
      assert result[:chart_data].key?(:ar_aging)
    end
  end
end
