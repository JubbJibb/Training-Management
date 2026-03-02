# frozen_string_literal: true

module Financials
  class PaymentsController < Financials::BaseController
    before_action :set_payment, except: [:index, :bulk_verify, :bulk_send_summary, :bulk_send_receipt, :bulk_export]

    def index
      @summary = Financials::PaymentTrackingSummaryQuery.call(filter_params)
      @payments = filtered_payments
      @payment = Attendee.find_by(id: params[:panel_id]) if params[:panel_id].present?
      @training_class = @payment&.training_class
      respond_to do |format|
        format.html
        format.turbo_stream
      end
    end

    def show
      @attendee = @payment
      @training_class = @payment.training_class
    end

    def panel
      @attendee = @payment
      @training_class = @payment.training_class
      @activity_logs = FinancialActionLog.where(subject_type: "Attendee", subject_id: @payment.id).order(created_at: :desc).limit(20).includes(:actor)
      render :panel, layout: false
    end

    def verify_slip
      @payment.update!(slip_verified_at: Time.current, payment_status: "Paid", payment_date: @payment.payment_date.presence || Date.current)
      log_activity("slip_verified", "Slip verified")
      redirect_to financials_payments_path(filter_params.to_h.merge(panel_id: @payment.id)), notice: "Payment verified."
    end

    def reject_slip
      @payment.update!(slip_verified_at: nil)
      log_activity("slip_rejected", "Slip rejected")
      redirect_to financials_payments_path(filter_params.to_h.merge(panel_id: @payment.id)), notice: "Slip rejected."
    end

    def issue_receipt
      next_no = next_receipt_number
      @payment.update!(document_status: "Receipt", receipt_no: next_no)
      log_activity("receipt_issued", "Receipt issued: #{next_no}")
      redirect_to financials_payments_path(filter_params.to_h.merge(panel_id: @payment.id)), notice: "Receipt #{next_no} issued."
    end

    def bulk_verify
      ids = params[:payment_ids].to_a.reject(&:blank?).map(&:to_i)
      Attendee.where(id: ids).find_each do |a|
        next unless a.payment_slips.attached?
        a.update!(slip_verified_at: Time.current, payment_status: "Paid", payment_date: a.payment_date.presence || Date.current)
        FinancialActionLog.create!(action_type: "slip_verified", subject_type: "Attendee", subject_id: a.id, actor_id: current_user&.id, status: "sent", metadata: {})
      end
      redirect_to financials_payments_path(filter_params.to_h), notice: "Verified #{ids.size} payment(s)."
    end

    def bulk_send_summary
      ids = params[:payment_ids].to_a.reject(&:blank?).map(&:to_i)
      ids.each do |payment_id|
        attendee = Attendee.find_by(id: payment_id)
        next unless attendee&.email.present?
        log = FinancialActionLog.create!(action_type: "send_payment_summary", subject_type: "Attendee", subject_id: attendee.id, actor_id: current_user&.id, status: "queued", metadata: {})
        SendPaymentSummaryJob.perform_later(payment_id: attendee.id, to: attendee.email, subject: default_subject_for(attendee), audit_log_id: log.id, actor_id: current_user&.id)
      end
      redirect_to financials_payments_path(filter_params.to_h), notice: "Queued #{ids.size} email(s)."
    end

    def bulk_send_receipt
      ids = params[:payment_ids].to_a.reject(&:blank?).map(&:to_i)
      # Same as send summary but could use a "receipt" email template if needed
      ids.each do |payment_id|
        attendee = Attendee.find_by(id: payment_id)
        next unless attendee&.email.present?
        log = FinancialActionLog.create!(action_type: "send_payment_summary", subject_type: "Attendee", subject_id: attendee.id, actor_id: current_user&.id, status: "queued", metadata: {})
        SendPaymentSummaryJob.perform_later(payment_id: attendee.id, to: attendee.email, subject: default_subject_for(attendee), audit_log_id: log.id, actor_id: current_user&.id)
      end
      redirect_to financials_payments_path(filter_params.to_h), notice: "Queued #{ids.size} receipt email(s)."
    end

    def bulk_export
      ids = params[:payment_ids].to_a.reject(&:blank?).map(&:to_i)
      redirect_to financials_payments_path(filter_params.to_h), alert: "Export selected: #{ids.size} row(s). Configure export job if needed."
    end

    def summary
      @training_class = @payment.training_class
      @customer = @payment.customer
      @registration = @payment

      respond_to do |format|
        format.html
        format.pdf do
          pdf_content = PaymentSummaryPdfGenerator.call(@payment)
          filename = PaymentSummaryPdfGenerator.filename_for(@payment)
          send_data pdf_content, filename: filename, type: "application/pdf", disposition: "attachment"
        rescue StandardError => e
          redirect_to summary_financials_payment_path(@payment), alert: "PDF could not be generated: #{e.message}"
        end
      end
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

      redirect_url = params[:redirect_url].presence || financials_payments_path(filter_params.to_h.merge(panel_id: @payment.id))
      redirect_to redirect_url, notice: "Queued to send."
    end

    private

    def set_payment
      @payment = Attendee.find_by(id: params[:id])
      unless @payment
        redirect_to financials_payments_path, alert: "Payment not found."
      end
    end

    def default_subject
      "Payment Summary — #{@payment.training_class.title} (#{@payment.training_class.date&.strftime('%Y-%m-%d') || '—'})"
    end

    def default_subject_for(attendee)
      "Payment Summary — #{attendee.training_class.title} (#{attendee.training_class.date&.strftime('%Y-%m-%d') || '—'})"
    end

    def filter_params
      params.permit(:period, :date_from, :date_to, :client_type, :status, :workflow_status, :class_id, :instructor, :overdue_only, :has_slip, :panel_id, :completed_today).to_h
    end

    def filtered_payments
      scope = Attendee.joins(:training_class).includes(:training_class, :customer).order("training_classes.date DESC", "attendees.id DESC")
      scope = scope.where(attendees: { participant_type: params[:client_type] }) if params[:client_type].in?(%w[Indi Corp])
      scope = scope.where(attendees: { payment_status: params[:status] }) if params[:status].in?(%w[Pending Paid])
      scope = scope.where("training_classes.date >= ?", params[:date_from]) if params[:date_from].present?
      scope = scope.where("training_classes.date <= ?", params[:date_to]) if params[:date_to].present?
      scope = scope.where(training_classes: { id: params[:class_id] }) if params[:class_id].present?
      scope = scope.where(training_classes: { instructor: params[:instructor] }) if params[:instructor].present?
      scope = scope.where("attendees.due_date < ?", Date.current) if params[:overdue_only] == "1"
      if params[:has_slip] == "1"
        scope = scope.where(id: ActiveStorage::Attachment.where(record_type: "Attendee", name: "payment_slips").select(:record_id))
      end
      if params[:completed_today] == "1"
        scope = scope.where(id: FinancialActionLog.where(subject_type: "Attendee", action_type: "send_payment_summary", status: "sent").where("updated_at >= ?", Date.current.beginning_of_day).select(:subject_id))
      end
      scope = apply_period_default(scope)
      list = scope.to_a
      if params[:workflow_status].present?
        list = list.select { |a| PaymentWorkflowStatus.for(a) == params[:workflow_status] }
      end
      list
    end

    def apply_period_default(scope)
      return scope if params[:date_from].present? || params[:date_to].present?
      return scope unless params[:period].blank? || params[:period] == "mtd"
      resolver = Financials::DateRangeResolver.new(period: "mtd")
      scope.where(training_classes: { date: resolver.start_date..resolver.end_date })
    end

    def log_activity(action_type, message)
      FinancialActionLog.create!(
        action_type: action_type,
        subject_type: "Attendee",
        subject_id: @payment.id,
        actor_id: current_user&.id,
        status: "sent",
        metadata: { message: message }
      )
    end

    def next_receipt_number
      y = Date.current.year
      max = Attendee.where("receipt_no LIKE ?", "RCP-#{y}-%").maximum(:receipt_no)
      n = max ? max.split("-").last.to_i + 1 : 1
      "RCP-#{y}-#{n.to_s.rjust(4, '0')}"
    end
  end
end
