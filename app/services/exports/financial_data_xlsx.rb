# frozen_string_literal: true

module Exports
  class FinancialDataXlsx < BaseExport
    def suggested_filename
      "financial-data-#{Date.current.iso8601}.xlsx"
    end

    def build_io
      require "caxlsx"
      attendees = scope_attendees.includes(:training_class).find_each

      p = Axlsx::Package.new
      p.workbook.add_worksheet(name: "Financial Data") do |sheet|
        sheet.add_row %w[Date Course Segment Channel Gross Discount Net VAT Total Cash_Received Outstanding Overdue Profit Margin], style: sheet.workbook.styles.add_style(b: true)
        attendees.each do |a|
          tc = a.training_class
          gross = a.gross_sales_amount
          disc = a.total_discount_amount * (a.seats || 1)
          net = a.total_price_before_vat
          vat = a.total_vat_amount
          total = a.total_final_price
          cash = a.payment_status == "Paid" ? total : 0
          out = a.payment_status == "Pending" ? total : 0
          over = (a.payment_status == "Pending" && a.due_date && a.due_date < Date.current) ? total : 0
          cost = tc.cost.to_f * (a.seats || 1) / [(tc.attendees.sum(:seats) || 1), 1].max
          profit = net - cost
          margin = net.positive? ? (profit / net * 100).round(1) : 0
          sheet.add_row [tc.date, tc.title, a.participant_type, a.source_channel.to_s, gross, disc, net, vat, total, cash, out, over, profit.round(2), margin]
        end
        sheet.sheet_view.pane do |pane|
          pane.top_left_cell = "A2"
          pane.state = :frozen_split
          pane.y_split = 1
        end
      end
      io = p.to_stream
      io.rewind
      io
    end
  end
end
