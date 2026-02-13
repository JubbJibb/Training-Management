# frozen_string_literal: true

module Exports
  # Combined revenue across classes with breakdown: by_month | by_class | by_payment_status
  class OverallRevenueSummaryXlsx < BaseExport
    BREAKDOWN_OPTIONS = %w[by_month by_class by_payment_status].freeze

    def suggested_filename
      "overall-revenue-summary-#{Date.current.iso8601}.xlsx"
    end

    def build_io
      require "caxlsx"
      attendees = scope_attendees.includes(:training_class, :promotions).to_a

      p = Axlsx::Package.new
      breakdown = (filters[:breakdown].presence || "by_class").to_s
      breakdown = "by_class" unless BREAKDOWN_OPTIONS.include?(breakdown)

      p.workbook.add_worksheet(name: "Summary") do |sheet|
        case breakdown
        when "by_month"
          add_by_month(sheet, attendees)
        when "by_class"
          add_by_class(sheet, attendees)
        when "by_payment_status"
          add_by_payment_status(sheet, attendees)
        else
          add_by_class(sheet, attendees)
        end
        sheet.sheet_view.pane { |pane| pane.top_left_cell = "A2"; pane.state = :frozen_split; pane.y_split = 1 }
      end
      io = p.to_stream
      io.rewind
      io
    end

    private

    def add_by_month(sheet, attendees)
      sheet.add_row %w[Month Gross Discounts Net VAT Total], style: sheet.workbook.styles.add_style(b: true)
      by_month = attendees.group_by { |a| a.training_class.date&.beginning_of_month }
      by_month.sort_by { |month, _| month || Date.current }.each do |month, list|
        next unless month
        gross = list.sum(&:gross_sales_amount)
        disc = list.sum { |a| a.total_discount_amount * (a.seats || 1) }
        net = list.sum(&:total_price_before_vat)
        vat = list.sum(&:total_vat_amount)
        total = list.sum(&:total_final_price)
        sheet.add_row [month.strftime("%Y-%m"), gross.round(2), disc.round(2), net.round(2), vat.round(2), total.round(2)]
      end
    end

    def add_by_class(sheet, attendees)
      sheet.add_row %w[Class Date Gross Discounts Net VAT Total], style: sheet.workbook.styles.add_style(b: true)
      by_class = attendees.group_by(&:training_class)
      by_class.sort_by { |tc, _| tc&.date || Date.current }.each do |tc, list|
        next unless tc
        gross = list.sum(&:gross_sales_amount)
        disc = list.sum { |a| a.total_discount_amount * (a.seats || 1) }
        net = list.sum(&:total_price_before_vat)
        vat = list.sum(&:total_vat_amount)
        total = list.sum(&:total_final_price)
        sheet.add_row [tc.title, tc.date, gross.round(2), disc.round(2), net.round(2), vat.round(2), total.round(2)]
      end
    end

    def add_by_payment_status(sheet, attendees)
      sheet.add_row %w[Payment_Status Count Gross Net VAT Total], style: sheet.workbook.styles.add_style(b: true)
      by_status = attendees.group_by { |a| a.payment_status.presence || "—" }
      by_status.each do |status, list|
        gross = list.sum(&:gross_sales_amount)
        net = list.sum(&:total_price_before_vat)
        vat = list.sum(&:total_vat_amount)
        total = list.sum(&:total_final_price)
        sheet.add_row [status, list.size, gross.round(2), net.round(2), vat.round(2), total.round(2)]
      end
    end
  end
end
