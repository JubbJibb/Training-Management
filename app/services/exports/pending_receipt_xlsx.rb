# frozen_string_literal: true

module Exports
  # Pending Receipt: attendees who have PAID but NO RECEIPT issued.
  # Columns for receipt: Name, Tax_ID, Address, Payment_Date, Amount, Slip. Optional filters: class_ids, date range.
  class PendingReceiptXlsx < BaseExport
    def suggested_filename
      "pending-receipts-#{Date.current.iso8601}.xlsx"
    end

    def build_io
      require "caxlsx"
      attendees = scope_attendees.includes(:training_class, :customer).to_a

      headers = %w[Name Tax_ID Address Payment_Date Amount Slip Class_Name]
      p = Axlsx::Package.new
      p.workbook.add_worksheet(name: "Pending Receipts") do |sheet|
        sheet.add_row headers, style: sheet.workbook.styles.add_style(b: true)
        attendees.each do |a|
          payment_date = a.respond_to?(:paid_at) && a.paid_at.present? ? a.paid_at : a.updated_at
          payment_date = payment_date.to_date if payment_date.respond_to?(:to_date)
          address = a.respond_to?(:document_billing_address) ? a.document_billing_address.to_s.gsub(/\n/, " ") : (a.address.to_s.gsub(/\n/, " "))
          slip_info = a.payment_slips.attached? ? a.payment_slips.map(&:filename).join("; ") : "—"
          sheet.add_row [
            a.name,
            a.tax_id.presence || a.customer&.tax_id.to_s,
            address.presence || "—",
            payment_date,
            a.total_amount.to_f,
            slip_info,
            a.training_class.title
          ]
        end
        sheet.sheet_view.pane { |pane| pane.top_left_cell = "A2"; pane.state = :frozen_split; pane.y_split = 1 }
      end
      io = p.to_stream
      io.rewind
      io
    end

    protected

    def scope_attendees
      scope = Attendee.attendees
        .joins(:training_class)
        .where(payment_status: "Paid")
        .where("(document_status IS NULL OR document_status = '' OR document_status != ?)", "Receipt")
      class_ids = class_ids_from_filters
      scope = scope.where(training_class_id: class_ids) if class_ids.present?
      range = date_range
      scope = scope.where("training_classes.date >= ? AND training_classes.date <= ?", range.begin, range.end)
      scope.includes(:training_class, :customer)
    end

    def class_ids_from_filters
      ids = filters[:class_ids] || filters["class_ids"]
      Array(ids).map(&:to_s).reject(&:blank?).map(&:to_i).reject(&:zero?)
    end
  end
end
