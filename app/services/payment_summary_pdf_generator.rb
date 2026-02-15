# frozen_string_literal: true

class PaymentSummaryPdfGenerator
  class << self
    # @param attendee [Attendee]
    # @return [String] PDF binary
    def call(attendee)
      new(attendee).call
    end

    def filename_for(attendee)
      new(attendee).filename
    end
  end

  def initialize(attendee)
    @attendee = attendee
    @training_class = attendee.training_class
  end

  def call
    require "prawn"
    require "prawn/table"

    io = StringIO.new
    Prawn::Document.new(page_size: "A4", margin: 36) do |pdf|
      Exports::PrawnFontHelper.apply_font(pdf) if defined?(Exports::PrawnFontHelper)
      pdf.font "Helvetica" unless pdf.respond_to?(:font) && pdf.font.name.to_s.include?("Thai")

      # Header
      pdf.text "Payment Summary", size: 16, style: :bold
      pdf.move_down 8
      pdf.text company_name, size: 10
      pdf.text company_address, size: 9
      pdf.text "Tax ID: #{company_tax_id}", size: 9
      pdf.move_down 16

      # Class & customer
      pdf.text "Training details", size: 12, style: :bold
      pdf.move_down 4
      data = [
        ["Class", @training_class.title],
        ["Date", @training_class.date&.strftime("%d/%m/%Y") || "—"],
        ["Customer", @attendee.name.presence || "—"],
        ["Company", @attendee.company.presence || "—"],
        ["Email", @attendee.email.presence || "—"]
      ]
      pdf.table(data, width: pdf.bounds.width, cell_style: { size: 10 })
      pdf.move_down 16

      # Summary table
      pdf.text "Summary", size: 12, style: :bold
      pdf.move_down 4
      summary_data = [
        ["Class", @training_class.title],
        ["Date", @training_class.date&.strftime("%d/%m/%Y") || "—"],
        ["Customer", @attendee.name.presence || "—"],
        ["Total Paid", "฿#{number_with_delimiter(@attendee.total_final_price.to_f.round(2))}"]
      ]
      pdf.table(summary_data, width: pdf.bounds.width, cell_style: { size: 10 })
      pdf.move_down 16

      # Pricing breakdown
      pdf.text "Pricing breakdown", size: 12, style: :bold
      pdf.move_down 4
      base = (@attendee.base_price * (@attendee.seats || 1)).round(2)
      discount = @attendee.total_discount_amount.to_f * (@attendee.seats || 1)
      before_vat = @attendee.total_price_before_vat.to_f.round(2)
      vat = @attendee.total_vat_amount.to_f.round(2)
      total = @attendee.total_final_price.to_f.round(2)
      pricing_data = [
        ["Base", "฿#{number_with_delimiter(base)}"],
        ["Discount", "-฿#{number_with_delimiter(discount.round(2))}"],
        ["Before VAT", "฿#{number_with_delimiter(before_vat)}"],
        ["VAT 7%", "฿#{number_with_delimiter(vat)}"],
        ["Total (incl. VAT)", "฿#{number_with_delimiter(total)}"]
      ]
      pdf.table(pricing_data, width: pdf.bounds.width, cell_style: { size: 10 })
      pdf.move_down 20

      pdf.text "This is an automated payment summary. For questions contact ODTTraining@odds.team.", size: 9, color: "666666"
    end.render(io)
    io.rewind
    io.read
  end

  def filename
    safe_name = @attendee.name.to_s.gsub(/[^\w\s-]/, "").strip.gsub(/\s+/, "_").presence || "Customer"
    date_str = @training_class.date&.strftime("%Y-%m-%d") || "nodate"
    "ODT_Payment_Summary_#{safe_name}_#{date_str}.pdf"
  end

  private

  def company_name
    "Odd-E (Thailand) Co., Ltd."
  end

  def company_address
    "2549/41-43 Phahonyothin, Lat Yao, Chatuchak, Bangkok 10900"
  end

  def company_tax_id
    Rails.application.config.x.company_tax_id.presence || "0-1055-56110-71-8"
  end

  def number_with_delimiter(n)
    n.to_s.sub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')
  end
end
