# frozen_string_literal: true

# Provides structured data for the Financial Dashboard Overview tab:
# key metrics (with trends), payment breakdown, financial breakdown, AR aging, chart data.
class FinancialOverviewService
  PERIOD_PRESETS = {
    "this_month" => :current_month,
    "last_month" => :last_month,
    "this_quarter" => :current_quarter,
    "this_year" => :current_year
  }.freeze

  def initialize(filters = {})
    @filters = filters
    @preset = filters[:preset].presence || "this_month"
    @start_date = resolve_start_date
    @end_date = resolve_end_date
  end

  def summary
    base = base_summary
    prev = previous_period_summary
    {
      metrics: key_metrics(base, prev),
      payment_status: payment_breakdown(base),
      financial_breakdown: breakdown_data(base),
      ar_aging: aging_summary(base),
      chart_data: chart_data(base),
      payment_timeline: payment_timeline_data,
      metrics_trend: trend_indicators(base, prev),
      collection_rate: base[:collection_rate_pct],
      days_sales_outstanding: calculate_dso(base),
      health_status: determine_health(base),
      period_label: period_label,
      start_date: @start_date,
      end_date: @end_date
    }
  end

  private

  def base_summary
    @base_summary ||= ::Finance::FinanceDashboardSummary.new(@filters.merge(preset: @preset)).call
  end

  def previous_period_summary
    return @prev_summary if defined?(@prev_summary)
    prev_range = previous_period_range
    return @prev_summary = {} if prev_range.blank?
    prev_filters = @filters.merge(start_date: prev_range.begin, end_date: prev_range.end, preset: nil)
    @prev_summary = ::Finance::FinanceDashboardSummary.new(prev_filters).call
  end

  def previous_period_range
    return nil unless @start_date && @end_date
    days = (@end_date - @start_date).to_i + 1
    prev_end = @start_date - 1
    prev_start = prev_end - days + 1
    prev_start..prev_end
  end

  def resolve_start_date
    return Date.parse(@filters[:start_date].to_s) if @filters[:start_date].present?
    case @preset
    when "this_month" then Date.current.beginning_of_month
    when "last_month" then Date.current.prev_month.beginning_of_month
    when "this_quarter" then Date.current.beginning_of_quarter
    when "this_year" then Date.current.beginning_of_year
    else @filters[:start_date].present? ? Date.parse(@filters[:start_date].to_s) : Date.current.beginning_of_month
    end
  end

  def resolve_end_date
    return Date.parse(@filters[:end_date].to_s) if @filters[:end_date].present?
    case @preset
    when "this_month" then Date.current.end_of_month
    when "last_month" then Date.current.prev_month.end_of_month
    when "this_quarter" then Date.current.end_of_quarter
    when "this_year" then Date.current.end_of_year
    else @filters[:end_date].present? ? Date.parse(@filters[:end_date].to_s) : Date.current.end_of_month
    end
  end

  def period_label
    case @preset
    when "this_month" then "This Month"
    when "last_month" then "Last Month"
    when "this_quarter" then "This Quarter"
    when "this_year" then "This Year"
    else [@start_date&.strftime("%b %d"), @end_date&.strftime("%b %d, %Y")].compact.join(" – ")
    end
  end

  def key_metrics(base, prev)
    total_revenue = base[:total_incl_vat].to_f
    paid = base[:cash_received].to_f
    outstanding = base[:outstanding].to_f
    seats = base[:seats_sold_total].to_i
    avg_per_seat = seats.positive? ? (base[:net_before_vat].to_f / seats).round(2) : 0

    prev_rev = prev[:total_incl_vat].to_f
    prev_paid = prev[:cash_received].to_f
    prev_out = prev[:outstanding].to_f
    prev_seats = prev[:seats_sold_total].to_i
    prev_avg = prev_seats.positive? ? (prev[:net_before_vat].to_f / prev_seats).round(2) : 0

    {
      total_revenue: total_revenue,
      paid: paid,
      outstanding: outstanding,
      avg_per_seat: avg_per_seat,
      trend_revenue: pct_change(prev_rev, total_revenue),
      trend_paid: pct_change(prev_paid, paid),
      trend_outstanding: pct_change(prev_out, outstanding),
      trend_avg_seat: prev_avg.positive? ? pct_change(prev_avg, avg_per_seat) : nil
    }
  end

  def pct_change(prev_val, current_val)
    return nil if prev_val.blank? || prev_val.zero?
    (((current_val - prev_val) / prev_val) * 100).round(1)
  end

  def payment_breakdown(base)
    total = base[:total_incl_vat].to_f
    paid = base[:cash_received].to_f
    pending = base[:outstanding].to_f
    overdue = base[:overdue_amount].to_f
    total_ar = pending
    paid_pct = total.positive? ? ((paid / total) * 100).round(1) : 0
    pending_pct = total.positive? ? ((pending / total) * 100).round(1) : 0
    overdue_pct = total.positive? ? ((overdue / total) * 100).round(1) : 0
    {
      paid: { amount: paid, percentage: paid_pct },
      pending: { amount: pending, percentage: pending_pct },
      overdue: { amount: overdue, percentage: overdue_pct },
      total_ar: total_ar
    }
  end

  def breakdown_data(base)
    gross = base[:gross_sales].to_f
    discount = base[:discount_total].to_f
    vat = base[:vat_amount].to_f
    total = base[:total_incl_vat].to_f
    gross_pct = gross.positive? ? 100.0 : 0
    discount_pct = gross.positive? ? ((discount / gross) * 100).round(1) : 0
    vat_pct = gross.positive? ? ((vat / gross) * 100).round(1) : 0
    {
      gross: gross,
      discount: discount,
      vat: vat,
      total: total,
      gross_pct: gross_pct,
      discount_pct: discount_pct,
      vat_pct: vat_pct
    }
  end

  def aging_summary(base)
    today = Date.current
    scope = Attendee.attendees.joins(:training_class).where(payment_status: "Pending").where.not(due_date: nil)
    scope = scope.where("training_classes.date >= ?", @start_date) if @start_date
    scope = scope.where("training_classes.date <= ?", @end_date) if @end_date
    scope = scope.where(training_class_id: @filters[:training_class_id]) if @filters[:training_class_id].present?
    scope = scope.corp if @filters[:segment] == "corporate"
    scope = scope.indi if @filters[:segment] == "individual"
    scope = scope.where(source_channel: @filters[:channel]) if @filters[:channel].present?
    pending_list = scope.includes(:training_class).to_a

    buckets_new = [
      { range: "0-30", label: "Current (0-30 days)", min: 0, max: 30, status: "ok" },
      { range: "30-60", label: "30-60 days", min: 31, max: 60, status: "warning" },
      { range: "60-90", label: "60-90 days", min: 61, max: 90, status: "warning" },
      { range: "90+", label: "90+ days", min: 91, max: 9999, status: "critical" }
    ].map do |b|
      list = pending_list.select { |a| a.due_date && (days = (today - a.due_date).to_i) && days >= b[:min] && days <= b[:max] }
      amount = list.sum(&:total_final_price).round(2)
      { **b, amount: amount, count: list.size }
    end
    total_outstanding = buckets_new.sum { |b| b[:amount] }
    buckets_new.each do |b|
      b[:percentage] = total_outstanding.positive? ? ((b[:amount] / total_outstanding) * 100).round(0) : 0
    end
    {
      buckets: buckets_new,
      total_outstanding: total_outstanding
    }
  end

  def chart_data(base)
    # Default: 6 months of monthly buckets (aligned with period end or current month)
    end_ref = @end_date || Date.current
    months = []
    d = end_ref
    6.times do
      month_start = d.beginning_of_month
      month_end = d.end_of_month
      scope = Attendee.attendees.joins(:training_class).where("training_classes.date >= ? AND training_classes.date <= ?", month_start, month_end)
      scope = scope.where(training_class_id: @filters[:training_class_id]) if @filters[:training_class_id].present?
      scope = scope.corp if @filters[:segment] == "corporate"
      scope = scope.indi if @filters[:segment] == "individual"
      scope = scope.where(source_channel: @filters[:channel]) if @filters[:channel].present?
      list = scope.includes(:training_class).to_a
      rev = list.sum(&:total_final_price).round(2)
      cash = list.select { |a| a.payment_status == "Paid" }.sum(&:total_final_price).round(2)
      ar = list.select { |a| a.payment_status == "Pending" }.sum(&:total_final_price).round(2)
      rate = rev.positive? ? ((cash / rev) * 100).round(1) : 0
      months.unshift({
        date_bucket: month_start.strftime("%b %Y"),
        revenue: rev,
        cash_received: cash,
        outstanding: ar,
        collection_rate: rate
      })
      d = d.prev_month
    end
    months
  end

  # Timeline of payments by payment_date (วันที่จ่ายเงิน) ในช่วงที่เลือก
  def payment_timeline_data
    return [] unless @start_date && @end_date
    scope = Attendee.attendees.joins(:training_class)
      .where(payment_status: "Paid")
      .where.not(payment_date: nil)
      .where(payment_date: @start_date..@end_date)
    scope = scope.where(training_class_id: @filters[:training_class_id]) if @filters[:training_class_id].present?
    scope = scope.corp if @filters[:segment] == "corporate"
    scope = scope.indi if @filters[:segment] == "individual"
    scope = scope.where(source_channel: @filters[:channel]) if @filters[:channel].present?
    list = scope.includes(:training_class).to_a
    # ใช้ display_payment_date เพื่อรวมกรณีที่ payment_date มาจากสลิป
    by_date = list.group_by { |a| a.display_payment_date&.to_date }.compact
    by_date.sort_by { |date, _| date }.map do |date, attendees|
      {
        date: date,
        date_label: date.strftime("%d %b %Y"),
        amount: attendees.sum(&:total_final_price).round(2),
        count: attendees.size
      }
    end
  end

  def trend_indicators(base, prev)
    prev_seats = prev[:seats_sold_total].to_i
    curr_seats = base[:seats_sold_total].to_i
    prev_avg = prev_seats.positive? ? (prev[:net_before_vat].to_f / prev_seats) : 0
    curr_avg = curr_seats.positive? ? (base[:net_before_vat].to_f / curr_seats) : 0
    {
      total_revenue: pct_change(prev[:total_incl_vat].to_f, base[:total_incl_vat].to_f),
      paid: pct_change(prev[:cash_received].to_f, base[:cash_received].to_f),
      outstanding: pct_change(prev[:outstanding].to_f, base[:outstanding].to_f),
      avg_per_seat: prev_avg.positive? ? pct_change(prev_avg, curr_avg) : nil
    }
  end

  def calculate_dso(base)
    return nil if base[:total_incl_vat].to_f.zero?
    days = (@end_date - @start_date).to_i + 1
    daily_sales = base[:total_incl_vat].to_f / days
    return nil if daily_sales.zero?
    (base[:outstanding].to_f / daily_sales).round(0)
  end

  def determine_health(base)
    rate = base[:collection_rate_pct].to_f
    overdue = base[:overdue_amount].to_f
    outstanding = base[:outstanding].to_f
    if rate >= 90 && overdue.zero?
      "excellent"
    elsif rate >= 75 && (outstanding.zero? || (overdue / outstanding) < 0.2)
      "good"
    elsif rate >= 50
      "fair"
    else
      "poor"
    end
  end
end
