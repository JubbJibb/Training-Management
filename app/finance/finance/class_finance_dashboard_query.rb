# frozen_string_literal: true

class Finance::ClassFinanceDashboardQuery
  VAT_RATE = 0.07

  def initialize(training_class, filters = {})
    @training_class = training_class
    @filters = filters
    @attendees = build_attendees_scope.to_a
  end

  def call
    {
      kpis: kpis,
      revenue_timeseries: revenue_timeseries,
      cash_timeseries: cash_timeseries,
      ar_aging: ar_aging,
      waterfall: waterfall,
      profitability: profitability,
      cost_by_category: cost_by_category,
      action_required: action_required,
      expense_list: expense_list,
      payment_status_list: payment_status_list,
      corporate_billing_overview: corporate_billing_overview
    }
  end

  private

  def build_attendees_scope
    scope = @training_class.attendees.attendees
    scope = scope.corp if @filters[:type].to_s == "Corp"
    scope = scope.indi if @filters[:type].to_s == "Indi"
    case @filters[:status].to_s
    when "Paid" then scope = scope.paid
    when "Pending" then scope = scope.where(payment_status: "Pending")
    when "Overdue" then scope = scope.where(payment_status: "Pending").where("due_date < ?", Date.current)
    end
    scope.includes(:promotions)
  end

  def gross_sales
    @gross_sales ||= @attendees.sum(&:gross_sales_amount).round(2)
  end

  def discount_total
    @discount_total ||= @attendees.sum { |a| a.total_discount_amount * (a.seats || 1) }.round(2)
  end

  def net_before_vat
    @net_before_vat ||= @attendees.sum(&:total_price_before_vat).round(2)
  end

  def vat_amount
    @vat_amount ||= @attendees.sum(&:total_vat_amount).round(2)
  end

  def total_revenue_incl_vat
    @total_revenue_incl_vat ||= @attendees.sum(&:total_final_price).round(2)
  end

  def cash_received
    @cash_received ||= @attendees.select { |a| a.payment_status == "Paid" }.sum(&:total_final_price).round(2)
  end

  def outstanding
    @outstanding ||= @attendees.select { |a| a.payment_status == "Pending" }.sum(&:total_final_price).round(2)
  end

  def collection_rate_pct
    return 0 if total_revenue_incl_vat.zero?
    ((cash_received / total_revenue_incl_vat) * 100).round(1)
  end

  def total_cost
    @training_class.total_cost.to_f.round(2)
  end

  def profit
    (net_before_vat - total_cost).round(2)
  end

  def gross_margin_pct
    return nil if net_before_vat.zero?
    ((profit / net_before_vat) * 100).round(1)
  end

  def seats_total
    @attendees.sum(&:seats) || 0
  end

  def kpis
    {
      total_revenue_incl_vat: total_revenue_incl_vat,
      net_revenue_before_vat: net_before_vat,
      gross_sales: gross_sales,
      total_discounts: discount_total,
      cash_received: cash_received,
      outstanding: outstanding,
      collection_rate_pct: collection_rate_pct,
      net_profit: profit,
      profit_margin_pct: gross_margin_pct
    }
  end

  def revenue_timeseries
    date_label = @training_class.date.strftime("%Y-%m-%d")
    [
      { date: date_label, label: @training_class.date.strftime("%d/%m/%y"), net_revenue: net_before_vat, cash_received: cash_received }
    ]
  end

  def cash_timeseries
    revenue_timeseries
  end

  def ar_aging
    today = Date.current
    pending_with_due = @attendees.select { |a| a.payment_status == "Pending" && a.due_date.present? }
    not_due = @attendees.select { |a| a.payment_status == "Pending" && (a.due_date.blank? || a.due_date >= today) }
    not_due_amount = not_due.sum(&:total_final_price).round(2)
    overdue = pending_with_due.select { |a| a.due_date < today }
    overdue_amount = overdue.sum(&:total_final_price).round(2)
    next_7_days = pending_with_due.select { |a| a.due_date >= today && a.due_date <= today + 7 }
    next_7_days_due = next_7_days.sum(&:total_final_price).round(2)

    buckets = [
      { range: "Not due", amount: not_due_amount, count: not_due.size },
      { range: "1–7", min: 1, max: 7, amount: 0, count: 0 },
      { range: "8–30", min: 8, max: 30, amount: 0, count: 0 },
      { range: "31–60", min: 31, max: 60, amount: 0, count: 0 },
      { range: "60+", min: 61, max: 9999, amount: 0, count: 0 }
    ]
    overdue.each do |a|
      days = (today - a.due_date).to_i
      amt = a.total_final_price
      b = buckets.find { |x| x.key?(:min) && days >= x[:min] && days <= x[:max] }
      if b
        b[:amount] += amt
        b[:count] += 1
      end
    end
    buckets.each { |b| b[:amount] = b[:amount].round(2) }

    {
      buckets: buckets,
      total_ar: outstanding,
      overdue_amount: overdue_amount,
      overdue_count: overdue.size,
      next_7_days_due: next_7_days_due
    }
  end

  def waterfall
    {
      gross_sales: gross_sales,
      discount_total: discount_total,
      net_before_vat: net_before_vat,
      vat_amount: vat_amount,
      total_incl_vat: total_revenue_incl_vat,
      discount_rate_pct: gross_sales.positive? ? ((discount_total / gross_sales) * 100).round(1) : 0,
      avg_revenue_per_seat: seats_total.positive? ? (net_before_vat / seats_total).round(2) : 0,
      avg_discount_per_seat: seats_total.positive? ? (discount_total / seats_total).round(2) : 0
    }
  end

  def profitability
    {
      total_cost: total_cost,
      profit: profit,
      gross_margin_pct: gross_margin_pct,
      cost_per_seat: seats_total.positive? ? (total_cost / seats_total).round(2) : nil,
      profit_per_seat: seats_total.positive? ? (profit / seats_total).round(2) : nil
    }
  end

  def cost_by_category
    total = total_cost
    rows = []
    base = @training_class.cost.to_f.round(2)
    rows << { category: "Base cost", amount: base, pct: total.positive? ? ((base / total) * 100).round(1) : 0 } if base.positive?
    expenses = @training_class.class_expenses
    by_cat = expenses.group_by { |e| e.category.presence || "อื่นๆ" }
    by_cat.each do |category, list|
      sum = list.sum(&:amount).round(2)
      next if sum.zero?
      pct = total.positive? ? ((sum / total) * 100).round(1) : 0
      rows << { category: category, amount: sum, pct: pct }
    end
    rows.sort_by { |h| -h[:amount] }
  end

  def action_required
    overdue = @attendees.select { |a| a.payment_status == "Pending" && a.due_date && a.due_date < Date.current }
    overdue_amount = overdue.sum(&:total_final_price).round(2)
    pending_receipt = @attendees.select { |a| a.payment_status == "Paid" && a.document_status != "Receipt" }
    top_outstanding = @attendees
      .select { |a| a.payment_status == "Pending" }
      .sort_by { |a| [-(a.due_date ? (Date.current - a.due_date).to_i : 0), -a.total_final_price] }
      .first(5)
      .map do |a|
        days = a.due_date ? (Date.current - a.due_date).to_i : nil
        { name: a.customer&.company_name.presence || a.name, amount: a.total_final_price, days_outstanding: days }
      end
    {
      overdue_count: overdue.size,
      overdue_amount: overdue_amount,
      pending_receipt_count: pending_receipt.size,
      top_outstanding: top_outstanding
    }
  end

  def expense_list
    @training_class.class_expenses.order(created_at: :desc).to_a
  end

  def payment_status_list
    @attendees.map do |a|
      {
        company: a.participant_type == "Corp" ? (a.company.presence || "—") : "—",
        contact: a.name,
        quotation_no: a.quotation_no.presence || "—",
        invoice_no: a.invoice_no.presence || "—",
        receipt_no: a.receipt_no.presence || "—",
        amount: a.total_final_price,
        due_date: a.due_date,
        status: a.payment_status.presence || "Pending",
        attendee: a
      }
    end
  end

  def corporate_billing_overview
    corp = @attendees.select { |a| a.participant_type == "Corp" }
    by_company = corp.group_by { |a| a.company.presence || "—" }
    by_company.map do |company, list|
      total = list.sum(&:total_final_price).round(2)
      paid = list.select { |a| a.payment_status == "Paid" }.sum(&:total_final_price).round(2)
      outstanding = total - paid
      status = if paid.zero?
        "Unpaid"
      elsif outstanding.positive?
        "Partial"
      else
        "Paid"
      end
      last_payment = list.select { |a| a.payment_status == "Paid" }.max_by { |a| a.updated_at }&.updated_at
      {
        company: company,
        total: total,
        paid: paid,
        outstanding: outstanding,
        status: status,
        last_payment: last_payment
      }
    end.sort_by { |h| -h[:outstanding] }
  end
end
