# frozen_string_literal: true

module Exports
  # Attendee master data for editing and re-upload. Customizable columns.
  # Format: Excel with headers matching import spec for re-import.
  class AttendeeMasterEditableXlsx < BaseExport
    DEFAULT_COLUMNS = %w[name email phone company title].freeze
    ALLOWED_COLUMNS = (DEFAULT_COLUMNS + %w[name_thai billing_name billing_address tax_id notes]).freeze

    def suggested_filename
      "attendee-master-#{Date.current.iso8601}.xlsx"
    end

    def build_io
      require "caxlsx"
      cols = columns_to_export
      attendees = scope_attendees.includes(:training_class, :customer)

      p = Axlsx::Package.new
      p.workbook.add_worksheet(name: "Attendees") do |sheet|
        header_row = cols.dup
        header_row << "training_class_id" << "attendee_id" # for re-import matching
        sheet.add_row header_row, style: sheet.workbook.styles.add_style(b: true)
        attendees.each do |a|
          row = cols.map { |c| attendee_value(a, c) }
          row << a.training_class_id << a.id
          sheet.add_row row
        end
        sheet.sheet_view.pane { |pane| pane.top_left_cell = "A2"; pane.state = :frozen_split; pane.y_split = 1 }
      end
      io = p.to_stream
      io.rewind
      io
    end

    protected

    def scope_attendees
      scope = Attendee.attendees.joins(:training_class)
      class_ids = Array(filters[:class_ids]).reject(&:blank?).map(&:to_i)
      scope = scope.where(training_class_id: class_ids) if class_ids.any?
      range = date_range
      scope = scope.where("training_classes.date >= ? AND training_classes.date <= ?", range.begin, range.end)
      scope.includes(:training_class, :customer)
    end

    private

    def columns_to_export
      requested = Array(filters[:columns]).reject(&:blank?).map(&:to_s)
      requested = DEFAULT_COLUMNS if requested.empty?
      (requested & ALLOWED_COLUMNS).presence || DEFAULT_COLUMNS
    end

    def attendee_value(a, col)
      case col
      when "name" then a.name
      when "email" then a.email
      when "phone" then a.phone.to_s
      when "company" then a.company.to_s
      when "title" then a.company.to_s # or a custom title field if you have one
      when "name_thai" then a.respond_to?(:name_thai) ? a.name_thai.to_s : ""
      when "billing_name" then a.respond_to?(:billing_name) ? a.billing_name.to_s : ""
      when "billing_address" then (a.respond_to?(:document_billing_address) ? a.document_billing_address : a.address).to_s
      when "tax_id" then a.tax_id.to_s
      when "notes" then a.notes.to_s
      else ""
      end
    end
  end
end
