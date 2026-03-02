# frozen_string_literal: true

class PaymentWorkflowStatus
  STATUSES = %w[pending awaiting_verification ready_receipt ready_send completed overdue].freeze
  BADGE_CLASS = {
    "pending" => "pt-status--pending",
    "awaiting_verification" => "pt-status--awaiting",
    "ready_receipt" => "pt-status--ready",
    "ready_send" => "pt-status--ready",
    "completed" => "pt-status--completed",
    "overdue" => "pt-status--overdue"
  }.freeze
  LABELS = {
    "pending" => "Pending",
    "awaiting_verification" => "Awaiting verification",
    "ready_receipt" => "Ready to issue receipt",
    "ready_send" => "Ready to send",
    "completed" => "Completed",
    "overdue" => "Overdue"
  }.freeze

  class << self
    def for(attendee)
      new(attendee).status
    end

    def badge_class(attendee)
      BADGE_CLASS.fetch(new(attendee).status, "pt-status--pending")
    end

    def label(attendee)
      LABELS.fetch(new(attendee).status, "Pending")
    end
  end

  def initialize(attendee)
    @attendee = attendee
  end

  def status
    return "overdue" if overdue?
    return "completed" if completed?
    return "ready_send" if ready_send?
    return "ready_receipt" if ready_receipt?
    return "awaiting_verification" if awaiting_verification?
    "pending"
  end

  private

  def overdue?
    @attendee.payment_status != "Paid" &&
      @attendee.due_date.present? &&
      @attendee.due_date < Date.current
  end

  def completed?
    payment_summary_sent? || (@attendee.payment_status == "Paid" && @attendee.document_status == "Receipt")
  end

  def payment_summary_sent?
    FinancialActionLog
      .where(subject_type: "Attendee", subject_id: @attendee.id, action_type: "send_payment_summary", status: "sent")
      .exists?
  end

  def ready_send?
    @attendee.document_status == "Receipt" && !payment_summary_sent?
  end

  def ready_receipt?
    (slip_verified? || @attendee.payment_status == "Paid") && @attendee.document_status != "Receipt"
  end

  def slip_verified?
    @attendee.respond_to?(:slip_verified_at) && @attendee.slip_verified_at.present?
  end

  def awaiting_verification?
    @attendee.payment_slips.attached? && !slip_verified? && @attendee.payment_status != "Paid"
  end
end
