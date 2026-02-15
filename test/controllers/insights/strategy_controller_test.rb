# frozen_string_literal: true

require "test_helper"

module Insights
  class StrategyControllerTest < ActionDispatch::IntegrationTest
    test "should get show" do
      get insights_strategy_url
      assert_response :success
    end
  end
end
