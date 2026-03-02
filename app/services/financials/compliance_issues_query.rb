# frozen_string_literal: true

module Financials
  class ComplianceIssuesQuery
    RULES = [
      { id: :paid_missing_receipt, label: "Paid but missing Receipt No.", severity: "high", check: ->(a) { a.payment_status == "Paid" && a.document_status != "Receipt" } },
      { id: :inv_missing_due_date, label: "Invoice No. present but missing Due date", severity: "medium", check: ->(a) { a.invoice_no.present? && a.due_date.blank? } },
      { id: :pending_after_class, label: "Pending > 7 days after class end", severity: "medium", check: ->(a) { a.payment_status == "Pending" && a.training_class.date && (Date.current - a.training_class.date).to_i > 7 } },
      { id: :corp_missing_tax_id, label: "Corporate customer missing Tax ID", severity: "high", check: ->(a) { a.participant_type == "Corp" && a.tax_id.blank? } },
      { id: :missing_invoice_no, label: "Missing Invoice No.", severity: "medium", check: ->(a) { a.invoice_no.blank? } },
      { id: :missing_slip, label: "Paid but slip not uploaded", severity: "medium", check: ->(a) { a.payment_status == "Paid" && !a.payment_slips.attached? } }
    ].freeze

    class << self
      def call(params = {})
        new(params).call
      end
    end

    def initialize(params = {})
      @params = params
      @resolver = Financials::DateRangeResolver.new(params)
      @routes = Rails.application.routes.url_helpers
    end

    def call
      scope = Attendee.attendees.joins(:training_class)
        .where(training_classes: { date: @resolver.start_date..@resolver.end_date })
      scope = scope.where(participant_type: "Corp") if @params[:corporate_only].to_s == "1"
      scope = scope.where(payment_status: "Pending").where("attendees.due_date < ?", Date.current) if @params[:overdue_only].to_s == "1"
      list = scope.includes(:training_class, :customer).to_a
      list = list.select { |a| RULES.any? { |r| r[:check].call(a) } } if @params[:missing_only].to_s == "1"

      issues = []
      list.each do |a|
        edit_link = @routes.edit_admin_training_class_attendee_path(a.training_class, a)
        RULES.each do |rule|
          next unless rule[:check].call(a)
          issues << {
            issue: rule[:label],
            entity_link: edit_link,
            entity_label: "#{a.billing_name.presence || a.name} — #{a.training_class.title}",
            severity: rule[:severity],
            owner: "—",
            due: a.due_date,
            quick_fix_link: edit_link
          }
        end
      end
      issues.sort_by! { |i| [i[:severity] == "high" ? 0 : 1, i[:due] || Date.current] }
    end
  end
end
