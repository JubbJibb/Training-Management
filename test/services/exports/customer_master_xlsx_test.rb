# frozen_string_literal: true

require "test_helper"

module Exports
  class CustomerMasterXlsxTest < ActiveSupport::TestCase
    setup do
      @service = CustomerMasterXlsx.new(filters: {}, include_sections: {}, include_custom_fields: false)
    end

    test "build_io returns a StringIO" do
      io = @service.build_io
      assert io.is_a?(StringIO)
      io.rewind
      # XLSX is a zip file, starts with PK
      header = io.read(4)
      assert header.start_with?("PK"), "XLSX should start with PK (zip signature)"
    end

    test "suggested_filename includes date" do
      assert_match(/customer-master-\d{4}-\d{2}-\d{2}\.xlsx/, @service.suggested_filename)
    end
  end
end
