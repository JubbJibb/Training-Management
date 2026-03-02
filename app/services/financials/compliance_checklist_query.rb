# frozen_string_literal: true

module Financials
  class ComplianceChecklistQuery
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
      scope = Attendee.attendees.joins(:training_class)
        .where(training_classes: { date: @resolver.start_date..@resolver.end_date })
      scope = scope.where(participant_type: "Corp") if @params[:corporate_only].to_s == "1"
      scope = scope.where(payment_status: "Pending").where("attendees.due_date < ?", Date.current) if @params[:overdue_only].to_s == "1"
      list = scope.includes(:training_class, :customer).to_a
      list = list.select { |a| missing_qt?(a) || missing_inv?(a) || missing_receipt?(a) || missing_tax?(a) || missing_slip?(a) } if @params[:missing_only].to_s == "1"
      list.map do |a|
        {
          attendee: a,
          link: Rails.application.routes.url_helpers.financials_payment_path(a),
          missing_qt: missing_qt?(a),
          missing_inv: missing_inv?(a),
          missing_receipt: missing_receipt?(a),
          missing_tax: missing_tax?(a),
          missing_slip: missing_slip?(a)
        }
      end
    end

    private

    def missing_qt?(a)
      a.quotation_no.blank?
    end

    def missing_inv?(a)
      a.invoice_no.blank?
    end

    def missing_receipt?(a)
      a.payment_status == "Paid" && a.document_status != "Receipt"
    end

    def missing_tax?(a)
      a.participant_type == "Corp" && a.tax_id.blank?
    end

    def missing_slip?(a)
      a.payment_status == "Paid" && !a.payment_slips.attached?
    end
  end
end
