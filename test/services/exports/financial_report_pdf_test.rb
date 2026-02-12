# frozen_string_literal: true

require "test_helper"

module Exports
  class FinancialReportPdfTest < ActiveSupport::TestCase
    setup do
      @service = FinancialReportPdf.new(filters: { period: "this_month" }, include_sections: {}, include_custom_fields: false)
    end

    test "build_io returns a StringIO" do
      io = @service.build_io
      assert io.is_a?(StringIO)
      io.rewind
      assert io.read.start_with?("%PDF")
    end

    test "suggested_filename includes date" do
      assert_match(/financial-report-\d{4}-\d{2}-\d{2}\.pdf/, @service.suggested_filename)
    end
  end
end
