# frozen_string_literal: true

require "test_helper"

module Clients
  class CorporateAccountsInsightsTest < ActiveSupport::TestCase
    test "call returns expected keys" do
      result = Clients::CorporateAccountsInsights.new(preset: "mtd").call
      assert result.key?(:kpis)
      assert result.key?(:accounts)
      assert result.key?(:at_risk_accounts)
      assert result.key?(:upcoming_unpaid_corporate)
      assert result.key?(:date_range)
      assert result[:kpis].key?(:corporate_revenue)
      assert result[:kpis].key?(:active_corporate_accounts)
    end
  end
end
