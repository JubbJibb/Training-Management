# frozen_string_literal: true

require "test_helper"

module Insights
  class BusinessInsightsTest < ActiveSupport::TestCase
    test "call returns expected keys" do
      result = Insights::BusinessInsights.new(preset: "mtd").call
      assert result.key?(:kpis)
      assert result.key?(:chart_data)
      assert result.key?(:top_programs)
      assert result.key?(:alerts)
      assert result.key?(:date_range)
      assert result[:kpis].key?(:total_revenue)
      assert result[:kpis].key?(:total_profit)
      assert result[:chart_data].key?(:revenue_by_program)
      assert result[:chart_data].key?(:revenue_trend)
    end
  end
end
