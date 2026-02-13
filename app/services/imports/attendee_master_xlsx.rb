# frozen_string_literal: true

module Imports
  # Validates and applies re-uploaded Attendee Master Excel (from Exports::AttendeeMasterEditableXlsx).
  # Expects columns: name, email, phone, company, ... + training_class_id, attendee_id for matching.
  # Updates existing attendees by attendee_id. For xlsx parsing requires the +roo+ gem.
  class AttendeeMasterXlsx
    ALLOWED_UPDATE_COLUMNS = %w[name email phone company name_thai billing_name billing_address tax_id notes].freeze
    REQUIRED_HEADERS = %w[email training_class_id attendee_id].freeze

    Result = Struct.new(:success?, :updated_count, :errors, :skipped, keyword_init: true)

    def initialize(io:, updated_by: nil)
      @io = io
      @updated_by = updated_by
      @errors = []
      @updated_count = 0
      @skipped = 0
    end

    def call
      sheet = open_sheet
      return result_failure("Could not open Excel file. Add gem 'roo' for xlsx import.") unless sheet

      headers = normalize_headers(sheet.row(1))
      return result_failure("Missing required headers: #{REQUIRED_HEADERS.join(', ')}") unless headers && (REQUIRED_HEADERS - headers).empty?

      attendee_id_idx = headers.index("attendee_id")
      return result_failure("Missing attendee_id column for re-import") unless attendee_id_idx

      (2..sheet.last_row).each do |row_num|
        row = sheet.row(row_num)
        next if row.blank?
        attendee_id = row[attendee_id_idx].to_s.strip
        next if attendee_id.blank?
        attendee = Attendee.find_by(id: attendee_id)
        if attendee.nil?
          @skipped += 1
          next
        end
        ALLOWED_UPDATE_COLUMNS.each do |col|
          idx = headers.index(col)
          next unless idx
          val = row[idx].to_s.strip
          next if val == attendee.read_attribute(col).to_s
          attendee.assign_attributes(col => val) if attendee.respond_to?("#{col}=")
        end
        if attendee.changed?
          attendee.save!
          @updated_count += 1
        end
      end
      Result.new(success?: true, updated_count: @updated_count, errors: @errors, skipped: @skipped)
    rescue StandardError => e
      @errors << e.message
      Result.new(success?: false, updated_count: @updated_count, errors: @errors, skipped: @skipped)
    end

    private

    def open_sheet
      return nil unless defined?(Roo)
      xlsx = Roo::Spreadsheet.open(@io, extension: :xlsx)
      xlsx.sheet(0)
    end

    def normalize_headers(row)
      return nil unless row.is_a?(Array)
      row.map { |c| c.to_s.strip.downcase.gsub(/\s+/, "_") }
    end

    def result_failure(msg)
      @errors << msg
      Result.new(success?: false, updated_count: 0, errors: @errors, skipped: @skipped)
    end
  end
end
