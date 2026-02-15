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
      payment_status_list: payment_status_list_with_derived,
      corporate_billing_overview: corporate_billing_overview,
      segment_split: segment_split,
      promotions_performance: promotions_performance,
      payment_intelligence: payment_intelligence,
      insights: insights
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
    scope = @training_class.class_expenses.order(created_at: :desc)
    scope = scope.where(category: @filters[:expense_category]) if @filters[:expense_category].to_s.present?
    if @filters[:expense_date_from].present?
      from = Date.parse(@filters[:expense_date_from].to_s) rescue nil
      scope = scope.where("created_at >= ?", from.beginning_of_day) if from
    end
    if @filters[:expense_date_to].present?
      to = Date.parse(@filters[:expense_date_to].to_s) rescue nil
      scope = scope.where("created_at <= ?", to.end_of_day) if to
    end
    scope.to_a
  end

  def payment_status_list
    @attendees.map do |a|
      due = a.due_date
      paid_at = a.display_payment_date
      status = a.payment_status.presence || "Pending"
      status = "Overdue" if status == "Pending" && due.present? && due < Date.current
      days_to_pay = (paid_at.present? && due.present?) ? (paid_at.to_date - due).to_i : nil
      {
        company: a.participant_type == "Corp" ? (a.company.presence || "—") : "—",
        contact: a.name,
        email: a.email.presence || "—",
        segment: a.participant_type.presence || "Indi",
        quotation_no: a.quotation_no.presence || "—",
        invoice_no: a.invoice_no.presence || "—",
        receipt_no: a.receipt_no.presence || "—",
        amount: a.total_final_price,
        due_date: due,
        payment_date: paid_at,
        status: status,
        days_to_pay: days_to_pay,
        attendee: a
      }
    end
  end

  def payment_status_list_with_derived
    payment_status_list
  end

  def segment_split
    indi = @attendees.select { |a| a.participant_type != "Corp" }
    corp = @attendees.select { |a| a.participant_type == "Corp" }
    {
      indi: {
        amount: indi.sum(&:total_final_price).round(2),
        count: indi.size,
        seats: indi.sum(&:seats).to_i
      },
      corp: {
        amount: corp.sum(&:total_final_price).round(2),
        count: corp.size,
        seats: corp.sum(&:seats).to_i
      }
    }
  end

  def promotions_performance
    promo_hash = {}
    @attendees.each do |a|
      base = a.base_price
      seats = (a.seats || 1).to_i
      a.active_promotions.each do |promo|
        key = promo.id
        promo_hash[key] ||= { promotion: promo, promotion_name: promo.display_name, seats_used: 0, discount_cost: 0, revenue: 0 }
        disc = promo.calculate_discount(base) * seats
        rev = a.total_price_before_vat
        promo_hash[key][:seats_used] += seats
        promo_hash[key][:discount_cost] += disc
        promo_hash[key][:revenue] += rev
      end
    end
    net = net_before_vat
    rows = promo_hash.values.map do |h|
      rev = h[:revenue].round(2)
      cost = h[:discount_cost].round(2)
      seats = h[:seats_used]
      avg = seats.positive? ? (rev / seats).round(2) : 0
      margin_pct = rev.positive? ? (((rev - cost) / rev) * 100).round(1) : nil
      promo = h[:promotion]
      promotion_type = promo.respond_to?(:discount_type) ? promo.discount_type : nil
      h.merge(
        discount_cost: cost,
        revenue: rev,
        avg_per_seat: avg,
        margin_impact_pct: margin_pct,
        promotion_type: promotion_type,
        net_revenue_share_pct: net.positive? ? ((rev / net) * 100).round(1) : nil,
        avg_discount_per_seat: seats.positive? ? (cost / seats).round(2) : 0
      ).except(:promotion)
    end
    return [] if rows.empty?
    max_seats = rows.map { |r| r[:seats_used] }.max
    max_rev = rows.map { |r| r[:revenue] }.max
    max_cost = rows.map { |r| r[:discount_cost] }.max
    rows.each do |r|
      r[:chips] = []
      r[:chips] << "Most Used" if max_seats.positive? && r[:seats_used] == max_seats
      r[:chips] << "Highest Revenue" if max_rev.positive? && r[:revenue] == max_rev
      r[:chips] << "Most Costly" if max_cost.positive? && r[:discount_cost] == max_cost
    end
    rows.sort_by { |r| -r[:revenue] }
  end

  def payment_intelligence
    paid = @attendees.select { |a| a.payment_status == "Paid" }
    paid_with_due = paid.select { |a| a.due_date.present? && a.display_payment_date.present? }
    days_list = paid_with_due.map { |a| (a.display_payment_date.to_date - a.due_date).to_i }
    avg_days = days_list.any? ? (days_list.sum.to_f / days_list.size).round(0) : nil
    under_7 = paid_with_due.count { |a| (a.display_payment_date.to_date - a.due_date).to_i <= 7 }
    pct_under_7 = paid.any? ? ((under_7.to_f / paid.size) * 100).round(1) : nil
    overdue_count = @attendees.count { |a| a.payment_status == "Pending" && a.due_date.present? && a.due_date < Date.current }
    pct_late = @attendees.any? ? ((overdue_count.to_f / @attendees.size) * 100).round(1) : nil
    {
      collection_rate_pct: collection_rate_pct,
      avg_days_to_pay: avg_days,
      pct_paid_under_7_days: pct_under_7,
      pct_late: pct_late
    }
  end

  def insights
    list = []
    seg = segment_split
    pay_int = payment_intelligence
    if seg[:corp][:count].positive? && pay_int[:avg_days_to_pay].present?
      list << "Corporate payments average #{pay_int[:avg_days_to_pay]} days to pay."
    end
    promo_rows = promotions_performance
    if promo_rows.any?
      most_costly = promo_rows.max_by { |r| r[:discount_cost] }
      if most_costly && discount_total.positive?
        pct = ((most_costly[:discount_cost] / discount_total) * 100).round(0)
        list << "#{most_costly[:promotion_name]} accounts for #{pct}% of discount cost."
      end
    end
    if gross_margin_pct.present? && gross_margin_pct >= 0
      list << "Margin is #{format('%.1f', gross_margin_pct)}%."
    end
    if collection_rate_pct >= 90
      list << "Collection rate is strong (#{format('%.1f', collection_rate_pct)}%)."
    elsif outstanding.positive?
      list << "#{format('%.2f', outstanding)} THB outstanding (AR)."
    end
    if profit.positive? && seats_total.positive?
      list << "Profit per seat: #{format('%.2f', profit / seats_total)} THB."
    end
    list.first(5)
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
