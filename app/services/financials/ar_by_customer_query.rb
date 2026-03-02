# frozen_string_literal: true

module Financials
  class ArByCustomerQuery
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
      pending = build_pending_scope.includes(:training_class, :customer)
      grouped = pending.group_by { |a| a.customer_id.presence || "guest_#{a.id}" }
      grouped.map do |key, list|
        customer = list.first.customer
        name = customer ? (customer.billing_name.presence || customer.name) : (list.first.billing_name.presence || list.first.name)
        outstanding = list.sum { |a| (a.total_final_price || 0) }
        oldest_due = list.map(&:due_date).compact.min
        days_overdue = oldest_due ? (@today - oldest_due).to_i : nil
        bucket = aging_bucket(days_overdue)
        last_activity = list.max_by { |a| a.updated_at }&.updated_at
        first_attendee = list.min_by { |a| a.due_date || Date.current }
        {
          customer_id: key,
          name: name,
          outstanding: outstanding,
          overdue: outstanding,
          oldest_due: oldest_due,
          bucket: bucket,
          last_activity: last_activity,
          payment_ids: list.map(&:id),
          link_to_first: first_attendee ? Rails.application.routes.url_helpers.financials_payment_path(first_attendee) : nil
        }
      end.sort_by { |r| -r[:outstanding] }
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

    def aging_bucket(days)
      return "0-7" if days.nil? || days <= 7
      return "8-14" if days <= 14
      return "15-30" if days <= 30
      return "31-60" if days <= 60
      "60+"
    end
  end
end
