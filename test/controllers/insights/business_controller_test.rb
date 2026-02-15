# frozen_string_literal: true

require "test_helper"

module Insights
  class BusinessControllerTest < ActionDispatch::IntegrationTest
    test "should get show" do
      get insights_url
      assert_response :success
    end

    test "should get show with preset mtd" do
      get insights_url, params: { preset: "mtd" }
      assert_response :success
    end

    test "should get show with custom date range" do
      get insights_url, params: { preset: "custom", start_date: "2025-01-01", end_date: "2025-01-31" }
      assert_response :success
    end
  end
end
