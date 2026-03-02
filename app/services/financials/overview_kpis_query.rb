# frozen_string_literal: true

module Financials
  class OverviewKpisQuery
    class << self
      def call(params = {})
        new(params).call
      end
    end

    def initialize(params = {})
      @params = params
      @resolver = Financials::DateRangeResolver.new(params)
      @attendees = build_attendees_scope
      @expenses_total = class_expenses_total
    end

    def call
      {
        revenue: revenue,
        revenue_mtd: revenue_in_range(mtd_range),
        revenue_ytd: revenue_in_range(ytd_range),
        collected_mtd: collected_in_range(mtd_range),
        booked: booked,
        outstanding: outstanding,
        overdue: overdue,
        overdue_count: overdue_count,
        profit: profit,
        document_completeness_pct: document_completeness_pct,
        expense_mtd: expense_in_range(mtd_range)
      }
    end

    private

    def build_attendees_scope
      # Only records with status = Attendee (excludes e.g. potential); filters by date range and optional client_type/status
      scope = Attendee.attendees.joins(:training_class).includes(:training_class, :customer)
        .where(training_classes: { date: @resolver.start_date..@resolver.end_date })
      scope = scope.where(participant_type: @params[:client_type]) if @params[:client_type].in?(%w[Indi Corp])
      scope = scope.where(payment_status: @params[:status]) if @params[:status].in?(%w[Pending Paid])
      scope
    end

    def class_expenses_total
      ClassExpense.joins(:training_class)
        .where(training_classes: { date: @resolver.start_date..@resolver.end_date })
        .sum(:amount)
    end

    def mtd_range
      Date.current.beginning_of_month..Date.current.end_of_month
    end

    def ytd_range
      Date.current.beginning_of_year..Date.current
    end

    def revenue
      @attendees.where(payment_status: "Paid").sum { |a| (a.total_final_price || 0) }
    end

    def revenue_in_range(range)
      Attendee.attendees.joins(:training_class)
        .where(training_classes: { date: range })
        .where(payment_status: "Paid")
        .sum { |a| (a.total_final_price || 0) }
    end

    def collected_in_range(range)
      revenue_in_range(range)
    end

    def expense_in_range(range)
      ClassExpense.joins(:training_class)
        .where(training_classes: { date: range })
        .sum(:amount)
    end

    def overdue_count
      # Only Attendee status + Pending + due_date past
      @attendees.where(payment_status: "Pending").where("attendees.due_date < ?", Date.current).count
    end

    def document_completeness_pct
      total = @attendees.count
      return 100.0 if total.zero?
      with_inv = @attendees.where.not(invoice_no: [nil, ""]).count
      with_receipt = @attendees.where(payment_status: "Paid").where(document_status: "Receipt").count
      needed = @attendees.where(payment_status: "Paid").count
      inv_ready = needed.zero? ? 100 : (with_inv.to_f / total * 100).round(1)
      receipt_ready = needed.zero? ? 100 : (with_receipt.to_f / needed * 100).round(1)
      ((inv_ready + receipt_ready) / 2.0).round(1)
    end

    def booked
      @attendees.sum { |a| (a.total_final_price || 0) }
    end

    # Unpaid/Outstanding: only Attendee status + payment_status Pending
    def outstanding
      @attendees.where(payment_status: "Pending").sum { |a| (a.total_final_price || 0) }
    end

    # Overdue amount: Attendee status + Pending + due_date < today
    def overdue
      @attendees.where(payment_status: "Pending").where("attendees.due_date < ?", Date.current).sum { |a| (a.total_final_price || 0) }
    end

    def profit
      (revenue - @expenses_total).round(2)
    end
  end
end
