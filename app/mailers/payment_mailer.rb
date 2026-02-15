# frozen_string_literal: true

class PaymentMailer < ApplicationMailer
  default from: "ODTTraining@odds.team"

  # Sends payment summary email with PDF attached.
  # Called from SendPaymentSummaryJob. pdf_content and pdf_filename are required for attachment.
  def payment_summary(attendee:, to:, cc: nil, subject:, body_message: nil, pdf_content: nil, pdf_filename: nil)
    @attendee = attendee
    @training_class = attendee.training_class
    @customer_name = attendee.name.presence || "Customer"
    @class_title = @training_class.title
    @class_date = @training_class.date&.strftime("%d/%m/%Y") || "—"
    @total_paid = attendee.total_final_price.to_f.round(2)
    @base = (attendee.base_price * (attendee.seats || 1)).round(2)
    @discount = (attendee.total_discount_amount.to_f * (attendee.seats || 1)).round(2)
    @before_vat = attendee.total_price_before_vat.to_f.round(2)
    @vat = attendee.total_vat_amount.to_f.round(2)
    @body_message = body_message

    if pdf_content.present? && pdf_filename.present?
      attachments[pdf_filename] = {
        mime_type: "application/pdf",
        content: pdf_content
      }
    end

    mail(
      to: to,
      cc: cc.presence,
      subject: subject,
      reply_to: "ODTTraining@odds.team"
    ) do |format|
      format.html
      format.text
    end
  end
end
