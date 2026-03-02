# frozen_string_literal: true

module Financials
  class ArAgingQuery
    BUCKETS = [
      [0, 7, "0-7"],
      [8, 14, "8-14"],
      [15, 30, "15-30"],
      [31, 60, "31-60"],
      [61, nil, "60+"]
    ].freeze

    class << self
      def call(params = {})
        new(params).call
      end
    end

    def initialize(params = {})
      @params = params
      @resolver = Financials::DateRangeResolver.new(params)
      @today = Date.current
    end

    def call
      buckets = BUCKETS.map do |min_days, max_days, label|
        scope = build_pending_scope
        # Overdue days = (today - due_date). 0-7 days overdue => due_date in [today-7, today)
        scope = scope.where("attendees.due_date >= ?", @today - max_days.days) if max_days
        scope = scope.where("attendees.due_date < ?", @today - min_days.days) if min_days.positive?
        amount = scope.sum("COALESCE(attendees.total_amount, 0) * COALESCE(attendees.seats, 1)")
        { label: label, min_days: min_days, max_days: max_days, amount: amount.to_f }
      end
      { buckets: buckets, total_outstanding: buckets.sum { |b| b[:amount] } }
    end

    private

    def build_pending_scope
      scope = Attendee.attendees.joins(:training_class)
        .where(payment_status: "Pending")
        .where("attendees.due_date IS NOT NULL AND attendees.due_date < ?", @today)
      scope = scope.where(training_classes: { date: @resolver.start_date..@resolver.end_date }) if @params[:period].present?
      scope = scope.where(participant_type: @params[:client_type]) if @params[:client_type].in?(%w[Indi Corp])
      scope
    end
  end
end
