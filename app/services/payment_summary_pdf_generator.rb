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

      # 1) Company header
      pdf.text "Payment Summary", size: 16, style: :bold
      pdf.move_down 8
      pdf.text company_name, size: 10
      pdf.text company_address, size: 9
      pdf.text "Tax ID: #{company_tax_id}", size: 9
      pdf.move_down 16

      # 2) Training details
      pdf.text "Training details", size: 12, style: :bold
      pdf.move_down 4
      training_rows = [
        ["Course / Class", @training_class.title],
        ["Date", @training_class.date&.strftime("%d/%m/%Y") || "—"]
      ]
      if @training_class.start_time.present? || @training_class.end_time.present?
        time_str = if @training_class.start_time.present? && @training_class.end_time.present?
          "#{@training_class.start_time.strftime('%H:%M')} – #{@training_class.end_time.strftime('%H:%M')}"
        else
          @training_class.start_time&.strftime('%H:%M') || @training_class.end_time&.strftime('%H:%M') || "—"
        end
        training_rows << ["Time", time_str]
      end
      pdf.table(training_rows, width: pdf.bounds.width, cell_style: { size: 10 })
      pdf.move_down 16

      # 3) Registrant details
      pdf.text "Registrant details", size: 12, style: :bold
      pdf.move_down 4
      registrant_rows = [
        ["Name", @attendee.name.presence || "—"],
        ["Email", @attendee.email.presence || "—"]
      ]
      if @attendee.participant_type == "Corp" || @attendee.company.present?
        registrant_rows << ["Company", @attendee.company.presence || @attendee.customer&.company || "—"]
        registrant_rows << ["Tax ID", @attendee.tax_id.presence || @attendee.customer&.tax_id || "—"]
        registrant_rows << ["Billing address", (@attendee.document_billing_address.presence || @attendee.customer&.billing_address || @attendee.customer&.address || "—").to_s[0, 80]]
      end
      pdf.table(registrant_rows, width: pdf.bounds.width, cell_style: { size: 10 })
      pdf.move_down 16

      # 4) Payment breakdown
      pdf.text "Payment breakdown", size: 12, style: :bold
      pdf.move_down 4
      base = (@attendee.base_price * (@attendee.seats || 1)).round(2)
      promotions = @attendee.active_promotions.to_a
      before_vat = @attendee.total_price_before_vat.to_f.round(2)
      vat = @attendee.total_vat_amount.to_f.round(2)
      total = @attendee.total_final_price.to_f.round(2)

      pricing_data = [["Base price", "฿#{number_with_delimiter(base)}"]]
      promotions.each do |promo|
        disc = (promo.calculate_discount(@attendee.base_price) * (@attendee.seats || 1)).round(2)
        pricing_data << ["Discount: #{promo.display_name}", "-฿#{number_with_delimiter(disc)}"]
      end
      total_discount = (@attendee.total_discount_amount.to_f * (@attendee.seats || 1)).round(2)
      if promotions.empty? && total_discount.positive?
        pricing_data << ["Discounts", "-฿#{number_with_delimiter(total_discount)}"]
      end
      pricing_data << ["Subtotal (before VAT)", "฿#{number_with_delimiter(before_vat)}"]
      pricing_data << ["VAT (7%)", "฿#{number_with_delimiter(vat)}"]
      pricing_data << ["Grand total", "฿#{number_with_delimiter(total)}"]

      pdf.table(pricing_data, width: pdf.bounds.width, cell_style: { size: 10 })
      pdf.move_down 16

      # 5) Payment method
      pdf.text "Payment method", size: 12, style: :bold
      pdf.move_down 4
      bank_data = [
        ["Bank", "Krung Thai Bank (ธ.กรุงไทย)"],
        ["Account type / Number", "Savings / Account number as per company"],
        ["Account holder", account_holder]
      ]
      pdf.table(bank_data, width: pdf.bounds.width, cell_style: { size: 10 })
      pdf.move_down 8
      pdf.text "After payment, please send your payment slip to ODTTraining@odds.team.", size: 9, color: "555555"
      pdf.move_down 16

      pdf.text "This is an automated payment summary. For questions contact ODTTraining@odds.team.", size: 9, color: "666666"
    end.render(io)
    io.rewind
    io.read
  end

  def filename
    safe_name = @attendee.name.to_s.gsub(/[^\w\s-]/, "").strip.gsub(/\s+/, "_").presence || "Customer"
    date_str = @training_class.date&.strftime("%Y-%m-%d") || "nodate"
    class_slug = @training_class.title.to_s.gsub(/[^\w\s-]/, "").strip.gsub(/\s+/, "_").presence || "Class"
    "Payment Summary - #{class_slug} - #{date_str}.pdf"
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

  def account_holder
    "Odd-E (Thailand) Co., Ltd."
  end

  def number_with_delimiter(n)
    n.to_s.sub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')
  end
end
