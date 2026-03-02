# frozen_string_literal: true

module Financials
  class ArByAttendeeQuery
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
      build_pending_scope.includes(:training_class, :customer).order(Arel.sql("attendees.due_date ASC NULLS LAST"), Arel.sql("attendees.id ASC")).map do |a|
        days_overdue = a.due_date ? (@today - a.due_date).to_i : nil
        {
          attendee: a,
          customer_name: a.billing_name.presence || a.name,
          customer_type: a.participant_type == "Corp" ? "Corporate" : "Individual",
          class_title: a.training_class.title,
          class_date: a.training_class.date,
          quotation_no: a.quotation_no.presence || "—",
          invoice_no: a.invoice_no.presence || "—",
          amount_due: (a.total_amount.to_f).positive? ? a.total_amount : (a.total_final_price || 0),
          due_date: a.due_date,
          aging_bucket: aging_bucket(days_overdue),
          payment_status: a.payment_status.presence || "Pending",
          link: Rails.application.routes.url_helpers.financials_payment_path(a),
          edit_link: Rails.application.routes.url_helpers.edit_admin_training_class_attendee_path(a.training_class, a)
        }
      end
    end

    private

    def build_pending_scope
      scope = Attendee.attendees.joins(:training_class).where(payment_status: "Pending")
      scope = scope.where("attendees.due_date IS NOT NULL AND attendees.due_date < ?", @today) if @params[:overdue_only] == "1" || @params[:overdue_only] == true
      scope = scope.where(training_classes: { date: @resolver.start_date..@resolver.end_date }) if @params[:period].present?
      scope = scope.where(participant_type: @params[:client_type]) if @params[:client_type].in?(%w[Indi Corp])
      scope
    end

    def aging_bucket(days)
      return "—" if days.nil?
      return "0-7" if days <= 7
      return "8-15" if days <= 15
      return "16-30" if days <= 30
      "31+"
    end
  end
end
