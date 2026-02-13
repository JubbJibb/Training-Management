# frozen_string_literal: true

module Exports
  # Class-specific financial report: Revenue, Discounts, VAT, Net per class.
  # Filters: multiple class selection, date range, payment status.
  class ClassFinancialReportXlsx < BaseExport
    def suggested_filename
      "class-financial-report-#{Date.current.iso8601}.xlsx"
    end

    def build_io
      require "caxlsx"
      attendees = scope_attendees.includes(:training_class, :promotions).to_a

      p = Axlsx::Package.new
      p.workbook.add_worksheet(name: "Class Financial Report") do |sheet|
        sheet.add_row %w[Class Date Attendee Email Revenue Discounts VAT Net Payment_Status], style: sheet.workbook.styles.add_style(b: true)
        attendees.each do |a|
          tc = a.training_class
          revenue = a.gross_sales_amount
          disc = a.total_discount_amount * (a.seats || 1)
          vat = a.total_vat_amount
          net = a.total_price_before_vat
          sheet.add_row [
            tc.title,
            tc.date,
            a.name,
            a.email,
            revenue.round(2),
            disc.round(2),
            vat.round(2),
            net.round(2),
            a.payment_status.to_s
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
      scope = Attendee.attendees.joins(:training_class)
      class_ids = Array(filters[:class_ids]).reject(&:blank?).map(&:to_i)
      scope = scope.where(training_class_id: class_ids) if class_ids.any?
      range = date_range
      scope = scope.where("training_classes.date >= ? AND training_classes.date <= ?", range.begin, range.end)
      scope = scope.where(payment_status: filters[:payment_status]) if filters[:payment_status].present? && %w[Paid Pending].include?(filters[:payment_status].to_s)
      scope
    end
  end
end
