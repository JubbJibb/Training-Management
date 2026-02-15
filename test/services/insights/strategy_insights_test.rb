# frozen_string_literal: true

require "test_helper"

module Insights
  class StrategyInsightsTest < ActiveSupport::TestCase
    test "call returns expected keys" do
      result = Insights::StrategyInsights.new(preset: "mtd").call
      assert result.key?(:kpis)
      assert result.key?(:chart_data)
      assert result.key?(:promotion_leaderboard)
      assert result.key?(:underperforming_promotions)
      assert result.key?(:date_range)
      assert result[:chart_data].key?(:funnel)
      assert result[:chart_data].key?(:revenue_by_promotion)
    end
  end
end
