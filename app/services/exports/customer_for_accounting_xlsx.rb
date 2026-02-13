# frozen_string_literal: true

module Exports
  class CustomerForAccountingXlsx < BaseExport
    def suggested_filename
      "customer-for-accounting-#{Date.current.iso8601}.xlsx"
    end

    def build_io
      require "caxlsx"
      range = date_range
      attendees = scope_attendees.includes(:training_class, :customer).find_each

      headers = %w[Company Tax_ID Address Contact Email Course Seats Net VAT Total Payment_Status Document_Status]
      headers += CustomField.for_entity("invoice").pluck(:label) if include_custom_fields

      p = Axlsx::Package.new
      p.workbook.add_worksheet(name: "Accounting") do |sheet|
        sheet.add_row headers, style: sheet.workbook.styles.add_style(b: true)
        attendees.each do |a|
          tc = a.training_class
          net = a.total_price_before_vat
          vat = a.total_vat_amount
          total = a.total_final_price
          company = a.customer&.company_name.presence || a.company.presence || a.name
          tax_id = a.tax_id.presence || a.customer&.tax_id.to_s
          address = (a.respond_to?(:document_billing_address) ? a.document_billing_address : (a.address.presence || a.customer&.billing_address.to_s)).to_s.gsub(/\n/, " ")
          row = [company, tax_id, address, a.name, a.email, tc.title, a.seats, net, vat, total, a.payment_status.to_s, a.document_status.to_s]
          row += invoice_custom_values(a) if include_custom_fields
          sheet.add_row row
        end
        sheet.sheet_view.pane { |pane| pane.top_left_cell = "A2"; pane.state = :frozen_split; pane.y_split = 1 }
      end
      io = p.to_stream
      io.rewind
      io
    end

    private

    def invoice_custom_values(attendee)
      CustomField.for_entity("invoice").map do |cf|
        CustomFieldValue.find_by(custom_field_id: cf.id, record_type: "Attendee", record_id: attendee.id)&.value
      end
    end
  end
end
