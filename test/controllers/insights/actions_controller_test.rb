# frozen_string_literal: true

require "test_helper"

module Insights
  class ActionsControllerTest < ActionDispatch::IntegrationTest
    test "should get show" do
      get insights_actions_url
      assert_response :success
    end
  end
end
