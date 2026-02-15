# frozen_string_literal: true

require "test_helper"

module Clients
  class ClientAnalysisTest < ActiveSupport::TestCase
    test "call returns expected keys" do
      result = Clients::ClientAnalysis.new(preset: "mtd").call
      assert result.key?(:kpis)
      assert result.key?(:top_spenders)
      assert result.key?(:revenue_concentration)
      assert result.key?(:revenue_by_channel)
      assert result.key?(:segment_mix)
      assert result.key?(:risk_outstanding)
      assert result.key?(:risk_no_activity)
      assert result[:kpis].key?(:total_clients)
    end
  end
end
