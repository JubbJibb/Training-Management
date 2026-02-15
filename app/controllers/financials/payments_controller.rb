# frozen_string_literal: true

module Financials
  class PaymentsController < Financials::BaseController
    before_action :set_payment

    def show
      @attendee = @payment
      @training_class = @payment.training_class
    end

    def download_pdf
      pdf_content = PaymentSummaryPdfGenerator.call(@payment)
      filename = PaymentSummaryPdfGenerator.filename_for(@payment)
      send_data pdf_content, filename: filename, type: "application/pdf", disposition: "attachment"
    rescue StandardError => e
      redirect_to financials_payment_path(@payment), alert: "PDF could not be generated: #{e.message}"
    end

    def send_summary
      to = params[:to].to_s.strip
      if to.blank?
        flash.now[:alert] = "To email is required."
        render :show, status: :unprocessable_entity
        return
      end
      unless to.match?(URI::MailTo::EMAIL_REGEXP)
        flash.now[:alert] = "Please enter a valid email address for To."
        render :show, status: :unprocessable_entity
        return
      end

      cc = params[:cc].to_s.strip.presence
      subject = params[:subject].to_s.strip.presence || default_subject
      message = params[:message].to_s.strip.presence

      audit_log = FinancialActionLog.create!(
        action_type: "send_payment_summary",
        actor_id: current_user&.id,
        subject_type: "Attendee",
        subject_id: @payment.id,
        metadata: {
          to: to,
          cc: cc,
          subject: subject,
          class_id: @payment.training_class_id,
          customer_id: @payment.customer_id,
          amount: @payment.total_final_price.to_f
        },
        status: "queued"
      )

      SendPaymentSummaryJob.perform_later(
        payment_id: @payment.id,
        to: to,
        cc: cc,
        subject: subject,
        message: message,
        audit_log_id: audit_log.id,
        actor_id: current_user&.id
      )

      redirect_to financials_payment_path(@payment), notice: "Queued to send."
    end

    private

    def set_payment
      @payment = Attendee.find_by(id: params[:id])
      unless @payment
        redirect_to financials_payment_tracking_path, alert: "Payment not found."
      end
    end

    def default_subject
      "Payment Summary — #{@payment.training_class.title} (#{@payment.training_class.date&.strftime('%Y-%m-%d') || '—'})"
    end
  end
end
