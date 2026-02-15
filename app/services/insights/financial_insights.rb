# frozen_string_literal: true

module Insights
  # Financial health: booked/collected/outstanding/overdue, expenses, net margin.
  # Charts: cash in vs out, AR aging. Table: overdue invoices. Breakdown: expense by category.
  class FinancialInsights
    CACHE_TTL = 5.minutes

    def initialize(params = {})
      @resolver = DateRangeResolver.new(params)
      @params = params
    end

    def call
      Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
        summary = finance_summary
        {
          kpis: kpis(summary),
          chart_data: {
            cash_in_vs_out: cash_in_vs_out(summary),
            ar_aging: ar_aging_buckets(summary)
          },
          overdue_invoices: overdue_invoices_table(summary),
          expense_by_category: expense_by_category
        }
      end.merge(date_range: { start_date: @resolver.start_date, end_date: @resolver.end_date, preset: @resolver.preset })
    end

    private

    def cache_key
      ["insights/financial", @resolver.start_date, @resolver.end_date].join("/")
    end

    def range
      @resolver.range
    end

    def finance_summary
      @finance_summary ||= Finance::FinanceDashboardSummary.new(
        preset: @resolver.preset == "custom" ? nil : @resolver.preset,
        start_date: range.begin,
        end_date: range.end
      ).call
    end

    def kpis(summary)
      total_expenses = expense_total
      net_before_vat = summary[:net_before_vat].to_f
      profit = (net_before_vat - total_expenses).round(2)
      net_margin = net_before_vat.positive? ? ((profit / net_before_vat) * 100).round(1) : 0
      {
        booked_revenue: summary[:total_incl_vat].to_f.round(2),
        collected_revenue: summary[:cash_received].to_f.round(2),
        outstanding: summary[:outstanding].to_f.round(2),
        overdue: summary[:overdue_amount].to_f.round(2),
        total_expenses: total_expenses,
        net_margin_pct: net_margin
      }
    end

    def expense_total
      class_ids = Attendee.attendees.joins(:training_class)
        .where("training_classes.date >= ? AND training_classes.date <= ?", range.begin, range.end)
        .distinct.pluck(:training_class_id)
      ClassExpense.where(training_class_id: class_ids).sum(:amount).to_f.round(2)
    end

    def cash_in_vs_out(_summary)
      months = (range.begin.to_date.beginning_of_month..range.end.to_date.end_of_month).select { |d| d == d.beginning_of_month }
      # SQLite: strftime for month key; use total_amount as proxy for cash received
      paid_by_month = Attendee.attendees.joins(:training_class).where(payment_status: "Paid")
        .where("training_classes.date >= ? AND training_classes.date <= ?", range.begin, range.end)
        .group("strftime('%Y-%m', training_classes.date)")
        .sum(:total_amount)
      expense_by_month = ClassExpense.joins(:training_class)
        .where("training_classes.date >= ? AND training_classes.date <= ?", range.begin, range.end)
        .group("strftime('%Y-%m', training_classes.date)")
        .sum(:amount)
      months.map do |month|
        key = month.strftime("%Y-%m")
        { label: month.strftime("%b %Y"), cash_in: paid_by_month[key].to_f.round(2), cash_out: expense_by_month[key].to_f.round(2) }
      end
    end

    def ar_aging_buckets(_summary)
      # 0-30, 31-60, 60+ days overdue (all pending with due_date < today)
      pending = Attendee.attendees.where(payment_status: "Pending").where("due_date IS NOT NULL AND due_date < ?", Date.current).to_a
      today = Date.current
      buckets = [
        { range: "0-30", min: 0, max: 30 },
        { range: "31-60", min: 31, max: 60 },
        { range: "60+", min: 61, max: 9999 }
      ]
      buckets.map do |b|
        list = pending.select { |a| a.due_date && (days = (today - a.due_date).to_i) && days >= b[:min] && days <= b[:max] }
        amount = list.sum(&:total_final_price).round(2)
        { range: b[:range], amount: amount, count: list.size }
      end
    end

    def overdue_invoices_table(summary)
      scope = Attendee.attendees
        .joins(:training_class).includes(:customer, :training_class)
        .where(payment_status: "Pending")
        .where("attendees.due_date IS NOT NULL AND attendees.due_date < ?", Date.current)
      scope = scope.where("training_classes.date >= ? AND training_classes.date <= ?", range.begin, range.end) if range.begin && range.end
      scope.order("attendees.due_date ASC").limit(50).map do |a|
        {
          client: a.customer&.company_name.presence || a.company.presence || a.name,
          invoice_no: a.invoice_no.presence || "—",
          due_date: a.due_date,
          amount: a.total_final_price,
          days_overdue: (Date.current - a.due_date).to_i,
          attendee_id: a.id,
          training_class_id: a.training_class_id,
          customer_id: a.customer_id
        }
      end
    end

    def expense_by_category
      class_ids = Attendee.attendees.joins(:training_class)
        .where("training_classes.date >= ? AND training_classes.date <= ?", range.begin, range.end)
        .distinct.pluck(:training_class_id)
      ClassExpense.where(training_class_id: class_ids).group(:category).sum(:amount).map do |cat, sum|
        { category: cat.presence || "Uncategorized", amount: sum.to_f.round(2) }
      end.sort_by { |h| -h[:amount] }
    end
  end
end
