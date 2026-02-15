# frozen_string_literal: true

require "test_helper"

module Insights
  class FinancialControllerTest < ActionDispatch::IntegrationTest
    test "should get show" do
      get insights_financial_url
      assert_response :success
    end
  end
end
