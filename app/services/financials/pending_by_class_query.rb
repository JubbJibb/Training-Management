# frozen_string_literal: true

module Financials
  # Groups attendees with payment_status = Pending by training_class (same filters as Payment Tracking).
  class PendingByClassQuery
    class << self
      def call(params = {})
        new(params).call
      end
    end

    def initialize(params = {})
      @params = params
    end

    def call
      scope = base_scope
      scope = scope.where("attendees.due_date < ?", Date.current) if @params[:overdue_only] == "1"
      scope = scope.where(id: Attendee.joins(:payment_slips_attachments).distinct.select(:id)) if @params[:has_slip] == "1"
      list = scope.includes(:training_class, :customer).order("training_classes.date ASC", "attendees.id ASC").to_a

      by_class = list.group_by(&:training_class_id)
      groups = by_class.map do |_tc_id, attendees|
        tc = attendees.first.training_class
        total = attendees.sum { |a| (a.total_amount.to_f).positive? ? a.total_amount : (a.total_final_price || 0).to_f }
        due_dates = attendees.map(&:due_date).compact
        earliest_due = due_dates.min
        {
          training_class: tc,
          class_date: tc.date,
          class_title: tc.title,
          attendees: attendees,
          count: attendees.size,
          total_amount: total,
          earliest_due_date: earliest_due
        }
      end
      # Sort by priority (overdue first), then by earliest due date, then by amount desc, then by class date
      groups.sort_by do |g|
        p = priority_rank(g)
        due = g[:earliest_due_date] || g[:class_date] || Date.current
        [-p, due, -g[:total_amount].to_f, g[:class_date].to_s, g[:class_title].to_s]
      end
    end

    private

    def base_scope
      # รายการค้างชำระ: สถานะ Attendee + Payment = Pending, ทุก Class
      scope = Attendee.attendees
        .joins(:training_class)
        .where(attendees: { payment_status: "Pending" })
      scope = apply_period(scope)
      scope = scope.where(attendees: { participant_type: @params[:client_type] }) if @params[:client_type].in?(%w[Indi Corp])
      scope = scope.where(training_classes: { id: @params[:class_id] }) if @params[:class_id].present?
      scope = scope.where(training_classes: { instructor: @params[:instructor] }) if @params[:instructor].present?
      scope
    end

    def apply_period(scope)
      # ไม่กรองตามช่วงวันที่ = แสดงทั้งหมดทุก Class
      return scope if @params[:period].blank? && @params[:date_from].blank? && @params[:date_to].blank?
      resolver_params = @params.slice(:period, :date_from, :date_to).merge(period: @params[:period].presence || "mtd")
      resolver = Financials::DateRangeResolver.new(resolver_params)
      scope.where(training_classes: { date: resolver.start_date..resolver.end_date })
    end

    # For sort: higher = more urgent. Overdue=3, Due soon=2, Upcoming=1, No payment=0
    def priority_rank(g)
      total = g[:total_amount].to_f
      return 0 if total.zero?
      due = g[:earliest_due_date] || g[:class_date]
      return 3 if due.present? && due < Date.current
      return 2 if due.present? && due >= Date.current && due <= Date.current + 7
      1
    end
  end
end
