# frozen_string_literal: true

class Finance::FinanceDashboardSummary
  def initialize(filters = {})
      @filters = filters
      @start_date = resolve_start_date
      @end_date = resolve_end_date
    end

    def call
      {
        total_incl_vat: total_incl_vat,
        net_before_vat: net_before_vat,
        vat_amount: vat_amount,
        gross_sales: gross_sales,
        discount_total: discount_total,
        discount_rate_pct: discount_rate_pct,
        cash_received: cash_received,
        outstanding: outstanding,
        collection_rate_pct: collection_rate_pct,
        overdue_amount: overdue_amount,
        overdue_count: overdue_count,
        max_overdue_days: max_overdue_days,
        invoices_pending_count: attendees.count { |a| a.payment_status == "Pending" },
        profit_before_vat: profit_before_vat,
        margin_pct: margin_pct,
        seats_sold_total: seats_sold_total,
        seats_corp: seats_corp,
        seats_indi: seats_indi,
        avg_discount_per_seat: avg_discount_per_seat,
        avg_revenue_per_seat: avg_revenue_per_seat,
        docs_missing_qt: docs_missing_qt,
        docs_missing_inv: docs_missing_inv,
        docs_missing_receipt: docs_missing_receipt,
        docs_missing_slip: docs_missing_slip,
        action_required_rows: action_required_rows,
        breakdown_by_course: breakdown_by_course,
        breakdown_by_segment: breakdown_by_segment,
        breakdown_by_channel: breakdown_by_channel,
        cash_trend_rows: cash_trend_rows,
        ar_aging_buckets: ar_aging_buckets,
        corporate_ledger_rows: corporate_ledger_rows,
        start_date: @start_date,
        end_date: @end_date
      }
    end

    private

    def base_scope
      @base_scope ||= build_base_scope
    end

    def build_base_scope
      scope = Attendee.attendees.joins(:training_class).includes(:training_class, :customer, :promotions).with_attached_payment_slips
      scope = scope.where("training_classes.date >= ?", @start_date) if @start_date
      scope = scope.where("training_classes.date <= ?", @end_date) if @end_date
      scope = scope.where(training_class_id: @filters[:training_class_id]) if @filters[:training_class_id].present?
      scope = scope.corp if @filters[:segment] == "corporate"
      scope = scope.indi if @filters[:segment] == "individual"
      scope = apply_status_filter(scope) if @filters[:status].present?
      scope = scope.where(source_channel: @filters[:channel]) if @filters[:channel].present?
      scope
    end

    def apply_status_filter(scope)
      case @filters[:status]
      when "paid" then scope.paid
      when "pending" then scope.where(payment_status: "Pending")
      when "overdue" then scope.where(payment_status: "Pending").where("due_date < ?", Date.current)
      when "no_document" then scope.where("COALESCE(document_status, '') = ''")
      else scope
      end
    end

    def resolve_start_date
      return @filters[:start_date] if @filters[:start_date].present?
      case @filters[:preset]
      when "this_month" then Date.current.beginning_of_month
      when "last_month" then Date.current.prev_month.beginning_of_month
      when "this_quarter" then Date.current.beginning_of_quarter
      when "this_year" then Date.current.beginning_of_year
      else nil
      end
    end

    def resolve_end_date
      return @filters[:end_date] if @filters[:end_date].present?
      case @filters[:preset]
      when "this_month" then Date.current.end_of_month
      when "last_month" then Date.current.prev_month.end_of_month
      when "this_quarter" then Date.current.end_of_quarter
      when "this_year" then Date.current.end_of_year
      else nil
      end
    end

    def attendees
      @attendees ||= base_scope.to_a
    end

    def gross_sales
      attendees.sum(&:gross_sales_amount).round(2)
    end

    def discount_total
      attendees.sum { |a| a.total_discount_amount * (a.seats || 1) }.round(2)
    end

    def net_before_vat
      attendees.sum(&:total_price_before_vat).round(2)
    end

    def vat_amount
      attendees.sum(&:total_vat_amount).round(2)
    end

    def total_incl_vat
      attendees.sum(&:total_final_price).round(2)
    end

    def cash_received
      attendees.select { |a| a.payment_status == "Paid" }.sum(&:total_final_price).round(2)
    end

    def outstanding
      attendees.select { |a| a.payment_status == "Pending" }.sum(&:total_final_price).round(2)
    end

    def collection_rate_pct
      return 0 if total_incl_vat.zero?
      ((cash_received / total_incl_vat) * 100).round(1)
    end

    def discount_rate_pct
      return 0 if gross_sales.zero?
      ((discount_total / gross_sales) * 100).round(1)
    end

    def overdue_list
      @overdue_list ||= attendees.select { |a| a.payment_status == "Pending" && a.due_date && a.due_date < Date.current }
    end

    def overdue_amount
      overdue_list.sum(&:total_final_price).round(2)
    end

    def overdue_count
      overdue_list.size
    end

    def max_overdue_days
      return nil if overdue_list.empty?
      overdue_list.map { |a| (Date.current - a.due_date).to_i }.max
    end

    def seats_sold_total
      attendees.sum(&:seats) || 0
    end

    def seats_corp
      attendees.select { |a| a.participant_type == "Corp" }.sum(&:seats) || 0
    end

    def seats_indi
      attendees.count { |a| a.participant_type == "Indi" }
    end

    def avg_discount_per_seat
      return 0 if seats_sold_total.zero?
      (discount_total / seats_sold_total).round(2)
    end

    def avg_revenue_per_seat
      return 0 if seats_sold_total.zero?
      (net_before_vat / seats_sold_total).round(2)
    end

    def total_cost
      class_ids = base_scope.distinct.pluck(:training_class_id)
      TrainingClass.where(id: class_ids).sum { |tc| tc.total_cost }.round(2)
    end

    def profit_before_vat
      return nil if total_cost.zero? && net_before_vat.zero?
      (net_before_vat - total_cost).round(2)
    end

    def margin_pct
      return nil if net_before_vat.zero?
      return 0 if total_cost.zero?
      (((net_before_vat - total_cost) / net_before_vat) * 100).round(1)
    end

    def docs_missing_qt
      attendees.count { |a| a.payment_status == "Pending" && a.document_status.blank? }
    end

    def docs_missing_inv
      attendees.count { |a| a.payment_status == "Pending" && a.document_status.to_s.in?(["", "QT"]) }
    end

    def docs_missing_receipt
      attendees.count { |a| a.payment_status == "Paid" && a.document_status != "Receipt" }
    end

    def docs_missing_slip
      attendees.select { |a| a.payment_status == "Paid" && !a.payment_slips.attached? }.size
    end

    def action_required_rows
      rows = []
      base_scope.includes(:training_class, :customer).each do |a|
        missing = missing_docs_for(a)
        next if missing.empty?
        rows << {
          company: a.customer&.company_name.presence || a.company.presence || "—",
          contact: a.name,
          class_name: a.training_class.title,
          missing_doc: missing.join(", "),
          amount: a.total_final_price,
          due_date: a.due_date,
          status: a.payment_status,
          attendee: a
        }
      end
      rows.sort_by { |r| [r[:due_date] || Date.new(9999), -r[:amount]] }
    end

    def missing_docs_for(attendee)
      list = []
      list << "QT" if attendee.payment_status == "Pending" && attendee.document_status.blank?
      list << "INV" if attendee.payment_status == "Pending" && attendee.document_status.in?([nil, "", "QT"])
      list << "Receipt" if attendee.payment_status == "Paid" && attendee.document_status != "Receipt"
      list << "Slip" if attendee.payment_status == "Paid" && !attendee.payment_slips.attached?
      list
    end

    def breakdown_by_course
      attendees.group_by(&:training_class).map do |tc, list|
        gross = list.sum(&:gross_sales_amount)
        discount = list.sum { |a| a.total_discount_amount * (a.seats || 1) }
        net = list.sum(&:total_price_before_vat)
        cash = list.select { |a| a.payment_status == "Paid" }.sum(&:total_final_price)
        out = list.sum(&:total_final_price) - cash
        cost = tc.total_cost
        profit = net - cost
        margin = net.positive? ? (((profit / net) * 100).round(1)) : nil
        {
          course: tc.title,
          course_id: tc.id,
          seats_sold: list.sum(&:seats),
          gross: gross.round(2),
          discount: discount.round(2),
          net_before_vat: net.round(2),
          cash_received: cash.round(2),
          outstanding: out.round(2),
          profit: profit.round(2),
          margin_pct: margin
        }
      end.sort_by { |h| -h[:net_before_vat] }
    end

    def breakdown_by_segment
      corp_net = attendees.select { |a| a.participant_type == "Corp" }.sum(&:total_price_before_vat).round(2)
      indi_net = attendees.select { |a| a.participant_type == "Indi" }.sum(&:total_price_before_vat).round(2)
      [
        { segment: "Corporate", seats: seats_corp, net_before_vat: corp_net },
        { segment: "Individual", seats: seats_indi, net_before_vat: indi_net }
      ]
    end

    def breakdown_by_channel
      attendees.group_by { |a| a.source_channel.presence || "—" }.map do |channel, list|
        attendees_count = list.size
        paid_count = list.count { |a| a.payment_status == "Paid" }
        net = list.sum(&:total_price_before_vat).round(2)
        conversion = attendees_count.positive? ? ((paid_count.to_f / attendees_count) * 100).round(1) : nil
        {
          channel: channel,
          leads: "—",
          attendees: attendees_count,
          paid: paid_count,
          conversion_pct: conversion,
          net_revenue: net
        }
      end.sort_by { |h| -h[:net_revenue] }
    end

    def cash_trend_rows
      return [] unless @start_date && @end_date
      rows = []
      (@start_date..@end_date).each_slice(7) do |week_dates|
        week_start = week_dates.first
        week_end = week_dates.last
        list = attendees.select { |a| a.training_class.date && a.training_class.date >= week_start && a.training_class.date <= week_end }
        rev_net = list.sum(&:total_price_before_vat).round(2)
        cash = list.select { |a| a.payment_status == "Paid" }.sum(&:total_final_price).round(2)
        out = list.select { |a| a.payment_status == "Pending" }.sum(&:total_final_price).round(2)
        rows << { date_bucket: "#{week_start.strftime('%d/%m')}–#{week_end.strftime('%d/%m')}", revenue_net: rev_net, cash_received: cash, outstanding: out }
      end
      rows
    end

    def ar_aging_buckets
      pending = attendees.select { |a| a.payment_status == "Pending" && a.due_date.present? }
      today = Date.current
      buckets = [
        { range: "0–7", min: 0, max: 7 },
        { range: "8–14", min: 8, max: 14 },
        { range: "15–30", min: 15, max: 30 },
        { range: "30+", min: 31, max: 9999 }
      ]
      buckets.map do |b|
        list = pending.select { |a| a.due_date && (days = (today - a.due_date).to_i) && days >= b[:min] && days <= b[:max] }
        amount = list.sum(&:total_final_price).round(2)
        top3 = list.sort_by { |a| -a.total_final_price }.first(3).map { |a| { name: a.customer&.company_name.presence || a.name, amount: a.total_final_price } }
        { range: b[:range], amount: amount, count: list.size, top_customers: top3 }
      end
    end

    def corporate_ledger_rows
      corp = attendees.select { |a| a.participant_type == "Corp" }
      by_company = corp.group_by { |a| a.customer&.company_name.presence || a.company.presence || "—" }
      by_company.map do |company, list|
        total_billed = list.sum(&:total_price_before_vat).round(2)
        cash = list.select { |a| a.payment_status == "Paid" }.sum(&:total_final_price).round(2)
        out = (list.sum(&:total_final_price) - cash).round(2)
        status = out > 0 ? "Pending" : "Paid"
        last_activity = list.max_by { |a| a.updated_at }&.updated_at
        {
          company: company,
          total_billed_net: total_billed,
          cash_received: cash,
          outstanding: out,
          status: status,
          last_activity: last_activity,
          attendee_ids: list.map(&:id)
        }
      end.sort_by { |h| -h[:outstanding] }
    end
  end
