# frozen_string_literal: true

module Exports
  # Complete attendee export with purpose-based column sets: quotation | invoice | receipt
  class AttendeeCompleteXlsx < BaseExport
    PURPOSE_COLUMNS = {
      "quotation" => %w[Class Date Name Email Company Phone Seats Unit_Price Discount Net VAT Total Quotation_No],
      "invoice" => %w[Class Date Name Email Company Tax_ID Billing_Address Seats Net VAT Total Invoice_No Payment_Status Due_Date],
      "receipt" => %w[Class Date Name Email Company Tax_ID Billing_Address Amount Receipt_No Payment_Date]
    }.freeze

    def suggested_filename
      "attendees-#{purpose}-#{Date.current.iso8601}.xlsx"
    end

    def build_io
      require "caxlsx"
      headers = PURPOSE_COLUMNS[purpose] || PURPOSE_COLUMNS["invoice"]
      attendees = scope_attendees.includes(:training_class, :customer)

      io = StringIO.new
      p = Axlsx::Package.new
      p.workbook.add_worksheet(name: purpose.titleize) do |sheet|
        sheet.add_row headers, style: sheet.workbook.styles.add_style(b: true)
        attendees.each do |a|
          sheet.add_row build_row(a, headers)
        end
        sheet.sheet_view.pane { |pane| pane.top_left_cell = "A2"; pane.state = :frozen_split; pane.y_split = 1 }
      end
      io = p.to_stream
      io.rewind
      io
    end

    protected

    def purpose
      p = filters[:purpose].to_s.presence || "invoice"
      PURPOSE_COLUMNS.key?(p) ? p : "invoice"
    end

    def scope_attendees
      scope = Attendee.attendees.joins(:training_class)
      class_ids = Array(filters[:class_ids]).reject(&:blank?).map(&:to_i)
      scope = scope.where(training_class_id: class_ids) if class_ids.any?
      range = date_range
      scope = scope.where("training_classes.date >= ? AND training_classes.date <= ?", range.begin, range.end)
      scope.includes(:training_class, :customer, :promotions)
    end

    private

    def build_row(a, headers)
      tc = a.training_class
      billing = a.respond_to?(:document_billing_address) ? a.document_billing_address : (a.address.to_s.gsub(/\n/, " "))
      row = []
      headers.each do |h|
        row << case h
        when "Class" then tc.title
        when "Date" then tc.date
        when "Name" then a.name
        when "Email" then a.email
        when "Company" then a.customer&.company_name.presence || a.company.to_s
        when "Phone" then a.phone.to_s
        when "Seats" then a.seats
        when "Unit_Price" then tc.price.to_f
        when "Discount" then (a.total_discount_amount * (a.seats || 1)).round(2)
        when "Net" then a.total_price_before_vat.round(2)
        when "VAT" then a.total_vat_amount.round(2)
        when "Total" then a.total_amount.to_f.round(2)
        when "Quotation_No" then a.quotation_no.to_s
        when "Tax_ID" then a.tax_id.to_s
        when "Billing_Address" then billing
        when "Invoice_No" then a.invoice_no.to_s
        when "Payment_Status" then a.payment_status.to_s
        when "Due_Date" then a.due_date&.to_s
        when "Amount" then a.total_amount.to_f.round(2)
        when "Receipt_No" then a.receipt_no.to_s
        when "Payment_Date" then a.updated_at.to_date.to_s
        else ""
        end
      end
      row
    end
  end
end
