# frozen_string_literal: true

module Financials
  class OverviewActionItemsQuery
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
      {
        overdue_invoices: overdue_invoices,
        missing_receipts: missing_receipts,
        pending_quotation: pending_quotation,
        documents_missing: documents_missing
      }
    end

    private

    def base_attendees
      Attendee.attendees.joins(:training_class).where(training_classes: { date: @resolver.start_date..@resolver.end_date })
    end

    def overdue_invoices
      base_attendees.where(payment_status: "Pending").where("attendees.due_date < ?", Date.current)
        .order("attendees.due_date ASC")
        .limit(20)
        .map { |a| { attendee: a, link: Rails.application.routes.url_helpers.financials_payment_path(a), label: "Overdue: #{a.billing_name.presence || a.name} — #{a.training_class.title}" } }
    end

    def missing_receipts
      base_attendees.where(payment_status: "Paid").where(document_status: ["QT", "INV"]).or(
        base_attendees.where(payment_status: "Paid").where(document_status: nil)
      ).limit(20).map { |a| { attendee: a, link: Rails.application.routes.url_helpers.financials_payment_path(a), label: "Missing receipt: #{a.billing_name.presence || a.name}" } }
    end

    def pending_quotation
      base_attendees.where(quotation_no: [nil, ""]).where(document_status: nil).or(
        base_attendees.where(quotation_no: [nil, ""]).where(document_status: "QT")
      ).limit(20).map { |a| { attendee: a, link: Rails.application.routes.url_helpers.financials_payment_path(a), label: "Pending QT: #{a.billing_name.presence || a.name}" } }
    end

    def documents_missing
      base_attendees.where(invoice_no: [nil, ""]).or(base_attendees.where(quotation_no: [nil, ""])).limit(20)
        .map { |a| { attendee: a, link: Rails.application.routes.url_helpers.financials_payment_path(a), label: "Doc missing: #{a.billing_name.presence || a.name} — #{a.training_class.title}" } }
    end
  end
end
