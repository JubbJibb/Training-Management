# frozen_string_literal: true

require "test_helper"

module Clients
  class AnalysisControllerTest < ActionDispatch::IntegrationTest
    test "should get show" do
      get clients_analysis_url
      assert_response :success
    end
  end
end
