# frozen_string_literal: true

module Financials
  # Top 5 overdue receivables for Financial Overview.
  # Returns array of { client_name, amount, bucket_label, days_overdue, link_path }.
  class OverviewTopOverdueQuery
    BUCKETS = [
      [0, 7, "0–7 days"],
      [8, 15, "8–15 days"],
      [16, 30, "16–30 days"],
      [31, nil, "31+ days"]
    ].freeze

    class << self
      def call(params = {})
        new(params).call
      end
    end

    def initialize(params = {})
      @params = params
      @resolver = Financials::DateRangeResolver.new(params)
    end

    def call
      scope = Attendee.attendees.joins(:training_class).includes(:training_class)
        .where(payment_status: "Pending")
        .where("attendees.due_date IS NOT NULL AND attendees.due_date < ?", Date.current)
        .where(training_classes: { date: @resolver.start_date..@resolver.end_date })
      scope = scope.where(participant_type: @params[:client_type]) if @params[:client_type].in?(%w[Indi Corp])
      today = Date.current
      scope.order("attendees.due_date ASC").limit(20).map do |a|
        due = a.due_date
        days = due ? (today - due).to_i : 0
        bucket = BUCKETS.find { |lo, hi, _| (hi.nil? ? days >= lo : (days >= lo && days <= hi)) }
        bucket_label = bucket ? bucket[2] : "31+ days"
        amount = (a.total_final_price || 0)
        {
          client_name: a.billing_name.presence || a.name,
          amount: amount,
          bucket_label: bucket_label,
          days_overdue: days,
          link_path: Rails.application.routes.url_helpers.financials_payment_path(a)
        }
      end.first(5)
    end
  end
end
