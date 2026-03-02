# frozen_string_literal: true

require "test_helper"

module Financials
  class OverviewControllerTest < ActionDispatch::IntegrationTest
    test "overview renders with KPI strip and ODT table header" do
      get financials_overview_path
      assert_response :success
      assert_select "table.table-financials"
      assert_select "table.table-financials thead th", minimum: 1
      assert_select ".financials-kpi-strip .financials-kpi-card", minimum: 1
    end
  end
end
