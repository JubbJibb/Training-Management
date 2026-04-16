# frozen_string_literal: true

module Financials
  class PaymentTrackingSummaryQuery
    class << self
      def call(params = {})
        new(params).call
      end
    end

    def initialize(params = {})
      @params = params
      @scope = base_scope
    end

    def call
      {
        all_count: @scope.count,
        pending: count_and_amount(:pending),
        awaiting_verification: count_and_amount(:awaiting_verification),
        overdue: count_and_amount(:overdue),
        ready_send: count_and_amount(:ready_send),
        completed_today: count_completed_today
      }
    end

    private

    def base_scope
      # รายการค้างชำระ: สถานะ Attendee + Payment = Pending, ทุก Class
      scope = Attendee.attendees
        .joins(:training_class)
        .where(attendees: { payment_status: "Pending" })
        .includes(:training_class, :customer)
      scope = apply_period(scope)
      scope = scope.where(attendees: { participant_type: @params[:client_type] }) if @params[:client_type].in?(%w[Indi Corp])
      scope = scope.where(training_classes: { id: @params[:class_id] }) if @params[:class_id].present?
      scope = scope.where(training_classes: { instructor: @params[:instructor] }) if @params[:instructor].present?
      scope = scope.where("attendees.due_date < ?", Date.current) if @params[:overdue_only] == "1"
      scope = scope.where(id: Attendee.joins(:payment_slips_attachments).distinct.select(:id)) if @params[:has_slip] == "1"
      scope
    end

    def apply_period(scope)
      # ไม่กรองตามช่วงวันที่ = แสดงทั้งหมดทุก Class
      return scope if @params[:period].blank? && @params[:date_from].blank? && @params[:date_to].blank?
      params = @params.merge(period: @params[:period].presence || "mtd")
      resolver = Financials::DateRangeResolver.new(params)
      scope.where(training_classes: { date: resolver.start_date..resolver.end_date })
    end

    def count_and_amount(status_key)
      list = @scope.to_a
      subset = list.select { |a| PaymentWorkflowStatus.for(a) == status_key.to_s }
      {
        count: subset.size,
        amount: subset.sum { |a| (a.total_amount.to_f).positive? ? a.total_amount : (a.total_final_price || 0).to_f }
      }
    end

    def count_completed_today
      FinancialActionLog
        .where(subject_type: "Attendee", action_type: "send_payment_summary", status: "sent")
        .where("updated_at >= ?", Date.current.beginning_of_day)
        .where(subject_id: @scope.select(:id))
        .distinct
        .count(:subject_id)
    end
  end
end
