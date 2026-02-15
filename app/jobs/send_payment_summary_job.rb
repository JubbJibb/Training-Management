# frozen_string_literal: true

class SendPaymentSummaryJob < ApplicationJob
  queue_as :default

  # @param payment_id [Integer] attendee id (payment = one attendee registration)
  # @param to [String] email to
  # @param cc [String, nil] optional cc
  # @param subject [String]
  # @param message [String, nil] optional body message
  # @param audit_log_id [Integer] FinancialActionLog id created when enqueued (status=queued)
  # @param actor_id [Integer, nil] AdminUser id who triggered send
  def perform(payment_id:, to:, cc: nil, subject:, message: nil, audit_log_id: nil, actor_id: nil)
    attendee = Attendee.find_by(id: payment_id)
    unless attendee
      update_audit_failed(audit_log_id, "Attendee not found")
      return
    end

    pdf_content = nil
    pdf_filename = nil
    begin
      pdf_content = PaymentSummaryPdfGenerator.call(attendee)
      pdf_filename = PaymentSummaryPdfGenerator.filename_for(attendee)
    rescue StandardError => e
      update_audit_failed(audit_log_id, "PDF generation failed: #{e.message}")
      return
    end

    PaymentMailer.payment_summary(
      attendee: attendee,
      to: to,
      cc: cc.presence,
      subject: subject,
      body_message: message.presence,
      pdf_content: pdf_content,
      pdf_filename: pdf_filename
    ).deliver_now
    update_audit_sent(audit_log_id)
  rescue StandardError => e
    update_audit_failed(audit_log_id, e.message)
    raise
  end

  private

  def update_audit_sent(audit_log_id)
    return unless audit_log_id
    log = FinancialActionLog.find_by(id: audit_log_id)
    log&.update!(status: "sent", error_message: nil)
  end

  def update_audit_failed(audit_log_id, error_message)
    return unless audit_log_id
    log = FinancialActionLog.find_by(id: audit_log_id)
    log&.update!(status: "failed", error_message: error_message)
  end
end
