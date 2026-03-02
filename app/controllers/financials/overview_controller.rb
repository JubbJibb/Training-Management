# frozen_string_literal: true

module Financials
  class OverviewController < Financials::BaseController
    def index
      @kpis = Financials::OverviewKpisQuery.call(filter_params)
      @action_items = Financials::OverviewActionItemsQuery.call(filter_params)
      @chart_data = Financials::OverviewChartsQuery.call(filter_params)
      @ar_aging_buckets = overview_ar_aging_buckets
      @cost_composition = Financials::OverviewCostCompositionQuery.call(filter_params)
      @trend_rows = Financials::OverviewTrendQuery.call(filter_params.merge(basis: basis))
      @alerts_summary = alerts_summary
      @top_overdue = Financials::OverviewTopOverdueQuery.call(filter_params)
    end

    def kpi_detail
      @metric = params[:metric].to_s.presence
      unless %w[revenue costs profit cash_received outstanding].include?(@metric)
        return head :unprocessable_entity
      end

      @detail_rows = kpi_detail_rows_for(@metric)
      @total = @detail_rows.sum { |r| (r[:amount] || 0).to_f }
      render partial: "financials/overview/kpi_detail_content", layout: false, content_type: "text/html"
    end

    private

    def kpi_detail_rows_for(metric)
      resolver = Financials::DateRangeResolver.new(filter_params)
      base_attendees = build_detail_attendees_scope(resolver)
      case metric
      when "revenue"
        scope = base_attendees.where(payment_status: "Paid")
        scope.order("training_classes.date DESC", "attendees.id").map do |a|
          amt = (a.total_final_price || 0)
          { label: a.document_billing_name.presence || a.name, meta: a.training_class&.title, amount: amt, link_path: financials_payment_path(a) }
        end
      when "cash_received"
        mtd = Date.current.beginning_of_month..Date.current.end_of_month
        base_mtd = Attendee.attendees.joins(:training_class).includes(:training_class)
          .where(training_classes: { date: mtd })
        base_mtd = base_mtd.where(participant_type: filter_params[:client_type]) if filter_params[:client_type].in?(%w[Indi Corp])
        base_mtd = base_mtd.where(payment_status: filter_params[:status]) if filter_params[:status].in?(%w[Pending Paid])
        base_mtd.where(payment_status: "Paid").order("training_classes.date DESC", "attendees.id").map do |a|
          amt = (a.total_final_price || 0)
          { label: a.document_billing_name.presence || a.name, meta: a.training_class&.title, amount: amt, link_path: financials_payment_path(a) }
        end
      when "outstanding"
        base_attendees.where(payment_status: "Pending").order("training_classes.date DESC", "attendees.id").map do |a|
          amt = (a.total_final_price || 0)
          { label: a.document_billing_name.presence || a.name, meta: a.training_class&.title, amount: amt, link_path: financials_payment_path(a), due_date: a.due_date }
        end
      when "costs"
        ClassExpense.joins(:training_class)
          .where(training_classes: { date: resolver.start_date..resolver.end_date })
          .order("training_classes.date DESC", "class_expenses.id")
          .map do |exp|
            { label: exp.description.presence || "Expense", meta: exp.training_class&.title, amount: exp.amount.to_f, link_path: nil }
          end
      when "profit"
        rev_scope = base_attendees.where(payment_status: "Paid")
        rev_rows = rev_scope.order("training_classes.date DESC").map do |a|
          amt = (a.total_final_price || 0)
          { label: a.document_billing_name.presence || a.name, meta: a.training_class&.title, amount: amt, link_path: financials_payment_path(a) }
        end
        cost_rows = ClassExpense.joins(:training_class)
          .where(training_classes: { date: resolver.start_date..resolver.end_date })
          .order("training_classes.date DESC")
          .map { |exp| { label: exp.description.presence || "Expense", meta: exp.training_class&.title, amount: -exp.amount.to_f, link_path: nil } }
        rev_rows.each { |r| r[:row_type] = "revenue" }
        cost_rows.each { |r| r[:row_type] = "cost" }
        (rev_rows + cost_rows).sort_by { |r| [r[:meta].to_s, r[:label].to_s] }
      else
        []
      end
    end

    def build_detail_attendees_scope(resolver)
      scope = Attendee.attendees.joins(:training_class).includes(:training_class)
        .where(training_classes: { date: resolver.start_date..resolver.end_date })
      scope = scope.where(participant_type: filter_params[:client_type]) if filter_params[:client_type].in?(%w[Indi Corp])
      scope = scope.where(payment_status: filter_params[:status]) if filter_params[:status].in?(%w[Pending Paid])
      scope
    end

    def basis
      params[:basis].to_s.presence || "accrual"
    end

    def alerts_summary
      overdue = @action_items[:overdue_invoices].to_a
      missing = @action_items[:missing_receipts].to_a
      {
        outstanding_count: (@kpis[:overdue_count] || 0).to_i,
        outstanding_amount: (@kpis[:overdue] || 0).to_f,
        missing_receipts_count: missing.size,
        negative_margin_classes_count: negative_margin_classes_count
      }
    end

    def negative_margin_classes_count
      resolver = Financials::DateRangeResolver.new(filter_params)
      TrainingClass.where(date: resolver.start_date..resolver.end_date).count do |tc|
        rev = tc.attendees.attendees.where(payment_status: "Paid").sum { |a| (a.total_final_price || 0) }
        cost = tc.cost.to_f + tc.class_expenses.sum(:amount).to_f
        rev < cost
      end
    end

    def filter_params
      params.permit(:period, :date_from, :date_to, :client_type, :status, :class_type, :instructor_id, :location, :basis).to_h.symbolize_keys
    end

    # AR aging buckets for overview: 0-7, 8-15, 16-30, 31+ days overdue
    def overview_ar_aging_buckets
      resolver = Financials::DateRangeResolver.new(filter_params)
      scope = Attendee.attendees.joins(:training_class)
        .where(payment_status: "Pending")
        .where("attendees.due_date IS NOT NULL AND attendees.due_date < ?", Date.current)
        .where(training_classes: { date: resolver.start_date..resolver.end_date })
      scope = scope.where(participant_type: filter_params[:client_type]) if filter_params[:client_type].in?(%w[Indi Corp])
      today = Date.current
      [
        { range: "0-7", amount: scope.where("attendees.due_date >= ?", today - 7.days).sum(:total_amount).to_f, count: scope.where("attendees.due_date >= ?", today - 7.days).count },
        { range: "8-15", amount: scope.where("attendees.due_date < ?", today - 7.days).where("attendees.due_date >= ?", today - 15.days).sum(:total_amount).to_f, count: scope.where("attendees.due_date < ?", today - 7.days).where("attendees.due_date >= ?", today - 15.days).count },
        { range: "16-30", amount: scope.where("attendees.due_date < ?", today - 15.days).where("attendees.due_date >= ?", today - 30.days).sum(:total_amount).to_f, count: scope.where("attendees.due_date < ?", today - 15.days).where("attendees.due_date >= ?", today - 30.days).count },
        { range: "31+", amount: scope.where("attendees.due_date < ?", today - 30.days).sum(:total_amount).to_f, count: scope.where("attendees.due_date < ?", today - 30.days).count }
      ]
    end
  end
end
