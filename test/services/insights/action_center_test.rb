# frozen_string_literal: true

require "test_helper"

module Insights
  class ActionCenterTest < ActiveSupport::TestCase
    test "call returns expected keys" do
      result = Insights::ActionCenter.new.call
      assert result.key?(:critical)
      assert result.key?(:warning)
      assert result.key?(:follow_up)
      assert result.key?(:task_queue)
      assert result[:critical].is_a?(Array)
      assert result[:task_queue].is_a?(Array)
    end
  end
end
