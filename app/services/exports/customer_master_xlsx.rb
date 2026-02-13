# frozen_string_literal: true

module Exports
  class CustomerMasterXlsx < BaseExport
    def suggested_filename
      "customer-master-#{Date.current.iso8601}.xlsx"
    end

    def build_io
      require "caxlsx"
      headers = %w[Type Company_Name Contact_Person Phone Email Tax_ID Address Segment Note]
      headers += CustomField.for_entity("customer").pluck(:label) if include_custom_fields

      p = Axlsx::Package.new
      p.workbook.add_worksheet(name: "Customers") do |sheet|
        sheet.add_row headers, style: sheet.workbook.styles.add_style(b: true)
        Customer.order(:email).find_each do |c|
          row = [
            c.participant_type.to_s,
            c.company_name,
            c.name,
            c.phone.to_s,
            c.email,
            c.tax_id.to_s,
            (c.billing_address.to_s.gsub(/\n/, " ") rescue c.billing_address.to_s),
            c.participant_type.to_s,
            ""
          ]
          row += custom_values_for(c) if include_custom_fields
          sheet.add_row row
        end
        sheet.sheet_view.pane { |pane| pane.top_left_cell = "A2"; pane.state = :frozen_split; pane.y_split = 1 }
      end
      io = p.to_stream
      io.rewind
      io
    end

    private

    def custom_values_for(record)
      CustomField.for_entity("customer").map do |cf|
        CustomFieldValue.find_by(custom_field_id: cf.id, record_type: "Customer", record_id: record.id)&.value
      end
    end
  end
end
