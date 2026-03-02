# frozen_string_literal: true

module Insights
  # Business Insights: funnel, conversion, channel attribution, repeat rate, top lists.
  # Extended for executive dashboard: KPIs with deltas/sparklines, revenue trends, best-selling courses, pricing, channel performance, cohort.
  class BusinessInsightsQuery
    PRICE_BUCKETS = [
      [0, 10_000, "<10k"],
      [10_000, 20_000, "10–20k"],
      [20_000, 30_000, "20–30k"],
      [30_000, nil, ">30k"]
    ].freeze

    def initialize(params = {})
      @resolver = DateRangeResolver.new(params)
      @params = params
      @course_id = params[:course_id].presence
      @channel = params[:channel].presence
      @compare_to_previous = params[:compare_to_previous].nil? ? true : params[:compare_to_previous].to_s == "true" || params[:compare_to_previous] == true
      @trend_by = params[:trend_by].presence || default_trend_by
    end

    def call
      trend = trend_data
      prev_range = @compare_to_previous ? @resolver.previous_period_range : nil
      prev_att = prev_range ? previous_period_attendees(prev_range) : []
      f = funnel_counts
      prev_f = prev_att.any? ? funnel_counts_for(prev_att) : { registered: 0, paid: 0, attended: 0 }
      rev = revenue_from(attendees)
      prev_rev = revenue_from(prev_att)
      paid = f[:paid].to_i
      prev_paid = prev_f[:paid].to_i
      avg_price = paid.positive? ? (rev / paid).round(2) : 0
      prev_avg = prev_paid.positive? ? (prev_rev / prev_paid).round(2) : 0
      cvr = f[:registered].positive? ? (f[:paid].to_f / f[:registered] * 100).round(1) : 0
      prev_cvr = prev_f[:registered].positive? ? (prev_f[:paid].to_f / prev_f[:registered] * 100).round(1) : 0
      repeat_pct = repeat_rate_pct
      prev_repeat = prev_att.any? ? repeat_rate_pct_for(prev_att) : 0
      margin_data = gross_margin_data

      kpis = build_kpis(
        rev: rev, prev_rev: prev_rev,
        paid: paid, prev_paid: prev_paid,
        avg_price: avg_price, prev_avg: prev_avg,
        cvr: cvr, prev_cvr: prev_cvr,
        repeat_pct: repeat_pct, prev_repeat: prev_repeat,
        margin_data: margin_data,
        trend: trend
      )

      exec_text = executive_summary_text(
        period_label: period_label,
        revenue: rev, paid: paid, cvr: cvr, repeat_pct: repeat_pct
      )

      revenue_trend = trend.map { |r| r[:revenue].to_f }
      best = best_selling_courses_with_sparklines(trend)

      {
        summary: summary_strip_data,
        funnel_data: funnel_data,
        channel_mix_data: channel_mix_data,
        trend_data: trend,
        cohort_heatmap_data: cohort_heatmap_data,
        top_channels: top_channels,
        top_courses: top_courses,
        top_spenders: top_spenders,
        repeat_learners: repeat_learners,
        date_range: { start_date: @resolver.start_date, end_date: @resolver.end_date, preset: @resolver.preset },
        trend_by: @trend_by.to_s,
        compare_to_previous_period: @compare_to_previous,
        previous_period: prev_range ? { start_date: prev_range.begin, end_date: prev_range.end } : nil,
        executive_summary: { text: exec_text },
        kpis: kpis,
        revenue_trend_series: revenue_trend,
        best_selling_courses: best,
        pricing_insights: pricing_insights_data(trend),
        channel_performance: channel_performance_data,
        returning_revenue_pct: returning_revenue_pct,
        margin_na_reason: margin_data[:na_reason]
      }
    end

    private

    def range
      @resolver.range
    end

    def base_scope
      @base_scope ||= Attendee.attendees
        .joins(:training_class)
        .where("training_classes.date >= ? AND training_classes.date <= ?", range.begin, range.end)
        .includes(:training_class, :customer)
    end

    def scope_with_filters
      s = base_scope
      # When training_classes.course_id exists: s = s.where(training_classes: { course_id: @course_id }) if @course_id.present?
      s = s.where("COALESCE(attendees.source_channel, '') = ?", @channel) if @channel.present? && @channel != "all"
      s
    end

    def attendees
      @attendees ||= scope_with_filters.to_a
    end

    def period_label
      case @resolver.preset
      when "last_7d" then "7 วันที่ผ่านมา"
      when "last_30d" then "30 วันที่ผ่านมา"
      when "last_90d" then "90 วันที่ผ่านมา"
      when "mtd" then "เดือนนี้ (MTD)"
      when "qtd" then "ไตรมาสนี้ (QTD)"
      when "ytd" then "ปีนี้ (YTD)"
      when "custom" then "#{@resolver.start_date} ถึง #{@resolver.end_date}"
      else "ช่วงที่เลือก"
      end
    end

    # Funnel: Lead (optional; no Lead model = use 0 or registered), Registered → Paid → Attended
    def funnel_counts
      reg = attendees.size
      paid = attendees.count { |a| a.payment_status == "Paid" }
      attended = attendees.count { |a| a.attendance_status == "มาเรียน" }
      # If you have a Lead model: lead_count = Lead.where(created_at: range).count
      lead_count = 0
      { lead: lead_count, registered: reg, paid: paid, attended: attended }
    end

    def summary_strip_data
      f = funnel_counts
      conv = f[:registered].positive? ? (f[:attended].to_f / f[:registered] * 100).round(1) : 0
      top_ch = top_channels.first
      top_cr = top_courses.first
      repeat_pct = repeat_rate_pct
      {
        period_label: period_label,
        lead: f[:lead],
        registered: f[:registered],
        paid: f[:paid],
        attended: f[:attended],
        conversion_pct: conv,
        top_channel: top_ch&.dig(:channel) || "—",
        top_course: top_cr&.dig(:course)&.to_s&.truncate(30) || "—",
        repeat_pct: repeat_pct
      }
    end

    def funnel_data
      f = funnel_counts
      [
        { label: "ลงทะเบียน", value: f[:registered] },
        { label: "ชำระเงิน", value: f[:paid] },
        { label: "เข้าเรียน", value: f[:attended] }
      ]
    end

    def channel_mix_data
      by_week = attendees.group_by { |a| a.training_class.date&.beginning_of_week }
      by_week.compact!
      weeks = (range.begin.to_date..range.end.to_date).select { |d| d == d.beginning_of_week }.uniq
      channels = attendees.map { |a| a.source_channel.presence || "อื่นๆ" }.uniq
      weeks.map do |w|
        week_attendees = by_week[w] || []
        row = { label: w.strftime("%d/%m") }
        channels.each { |ch| row[ch] = week_attendees.count { |a| (a.source_channel.presence || "อื่นๆ") == ch } }
        row
      end
    end

    def trend_data
      if @trend_by.to_s.downcase == "week"
        trend_data_by_week
      else
        trend_data_by_day
      end
    end

    def default_trend_by
      return "day" unless range && range.begin && range.end
      days_count = (range.end.to_date - range.begin.to_date).to_i + 1
      days_count > 14 ? "week" : "day"
    end

    def trend_data_by_day
      by_day = attendees.group_by { |a| a.training_class.date }
      days = (range.begin.to_date..range.end.to_date).to_a
      days.map do |d|
        list = by_day[d] || []
        rev = list.select { |a| a.payment_status == "Paid" }.sum { |a| (a.total_final_price || 0).to_f }
        {
          date: d,
          label: d.strftime("%d/%m"),
          registered: list.size,
          paid: list.count { |a| a.payment_status == "Paid" },
          attended: list.count { |a| a.attendance_status == "มาเรียน" },
          revenue: rev
        }
      end
    end

    def trend_data_by_week
      by_week = attendees.group_by { |a| (a.training_class.date&.to_date)&.beginning_of_week }
      by_week.delete(nil)
      week_starts = (range.begin.to_date..range.end.to_date).map(&:beginning_of_week).uniq.sort
      week_starts.map do |week_start|
        week_end = week_start + 6.days
        list = by_week[week_start] || []
        rev = list.select { |a| a.payment_status == "Paid" }.sum { |a| (a.total_final_price || 0).to_f }
        {
          date: week_start,
          label: "w/c #{week_start.strftime('%d/%m')}",
          registered: list.size,
          paid: list.count { |a| a.payment_status == "Paid" },
          attended: list.count { |a| a.attendance_status == "มาเรียน" },
          revenue: rev
        }
      end
    end

    def repeat_rate_pct
      customer_ids = attendees.map(&:customer_id).compact.uniq
      return 0 if customer_ids.empty?
      repeat_count = customer_ids.count { |cid| Attendee.attendees.where(customer_id: cid).count > 1 }
      (repeat_count.to_f / customer_ids.size * 100).round(1)
    end

    def cohort_heatmap_data
      # Rows = first purchase month (first class date per customer), Cols = month offset 1, 2, 3...
      # Cells = % of that cohort that came back in that month
      first_by_customer = Attendee.attendees
        .joins(:training_class)
        .where.not(customer_id: nil)
        .group("attendees.customer_id")
        .minimum("training_classes.date")
      return { row_labels: [], col_labels: [], cells: [] } if first_by_customer.empty?

      months = first_by_customer.values.compact.uniq.map(&:beginning_of_month).uniq.sort
      col_offsets = [1, 2, 3]
      col_labels = col_offsets.map { |o| "เดือน+#{o}" }
      cells = months.map do |month_start|
        cohort_customers = first_by_customer.select { |_cid, d| d&.beginning_of_month == month_start }.keys
        col_offsets.map do |offset|
          target_month = month_start + offset.months
          returned = cohort_customers.count do |cid|
            Attendee.attendees.joins(:training_class)
              .where(customer_id: cid)
              .where("training_classes.date >= ? AND training_classes.date <= ?", target_month.beginning_of_month, target_month.end_of_month)
              .exists?
          end
          cohort_customers.any? ? (returned.to_f / cohort_customers.size * 100).round(0) : 0
        end
      end
      {
        row_labels: months.map { |m| m.strftime("%b %Y") },
        col_labels: col_labels,
        cells: cells
      }
    end

    def top_channels
      by_channel = attendees.group_by { |a| a.source_channel.presence || "อื่นๆ" }
      by_channel.map do |ch, list|
        paid = list.count { |a| a.payment_status == "Paid" }
        cvr = list.any? ? (paid.to_f / list.size * 100).round(1) : 0
        { channel: ch, leads: list.size, paid: paid, cvr: cvr }
      end.sort_by { |h| -h[:leads] }.first(10)
    end

    def top_courses
      by_course = attendees.group_by { |a| a.training_class.title }
      by_course.map do |title, list|
        rev = list.sum(&:total_final_price).to_f.round(2)
        paid = list.count { |a| a.payment_status == "Paid" }
        cvr = list.any? ? (paid.to_f / list.size * 100).round(1) : 0
        { course: title, revenue: rev, paid_count: paid, cvr: cvr }
      end.sort_by { |h| -h[:revenue] }.first(10)
    end

    def top_spenders
      by_customer = attendees.group_by(&:customer_id).compact
      by_customer.map do |cid, list|
        cust = list.first&.customer
        total = list.sum(&:total_final_price).to_f.round(2)
        last_date = list.map { |a| a.training_class.date }.compact.max
        { customer: cust&.name || "—", total_paid: total, classes_attended: list.size, last_activity: last_date }
      end.sort_by { |h| -h[:total_paid] }.first(10)
    end

    def repeat_learners
      customer_ids = attendees.map(&:customer_id).compact.uniq
      repeat = customer_ids.select { |cid| Attendee.attendees.where(customer_id: cid).count > 1 }
      repeat.map do |cid|
        cust = Customer.find_by(id: cid)
        atts = Attendee.attendees.where(customer_id: cid).includes(:training_class)
        count = atts.count
        fav = atts.map { |a| a.training_class.title }.tally.max_by { |_, v| v }&.first || "—"
        rate = (count > 1 ? ((count - 1).to_f / count * 100) : 0).round(1)
        { customer: cust&.name || "—", num_classes: count, repeat_rate: rate, favorite_course: fav.to_s.truncate(24) }
      end.sort_by { |h| -h[:num_classes] }.first(10)
    end

    def previous_period_attendees(prev_range)
      return [] unless prev_range
      s = Attendee.attendees
        .joins(:training_class)
        .where("training_classes.date >= ? AND training_classes.date <= ?", prev_range.begin, prev_range.end)
        .includes(:training_class, :customer)
      s = s.where("COALESCE(attendees.source_channel, '') = ?", @channel) if @channel.present? && @channel != "all"
      s.to_a
    end

    def revenue_from(list)
      list.select { |a| a.payment_status == "Paid" }.sum { |a| (a.total_final_price || 0).to_f }
    end

    def funnel_counts_for(list)
      reg = list.size
      paid = list.count { |a| a.payment_status == "Paid" }
      attended = list.count { |a| a.attendance_status == "มาเรียน" }
      { lead: 0, registered: reg, paid: paid, attended: attended }
    end

    def repeat_rate_pct_for(list)
      customer_ids = list.map(&:customer_id).compact.uniq
      return 0 if customer_ids.empty?
      repeat_count = customer_ids.count { |cid| Attendee.attendees.where(customer_id: cid).count > 1 }
      (repeat_count.to_f / customer_ids.size * 100).round(1)
    end

    def gross_margin_data
      class_ids = attendees.map(&:training_class_id).uniq
      return { margin_thb: 0, margin_pct: 0, revenue: 0, cost: 0, na_reason: "ไม่มีข้อมูลต้นทุน" } if class_ids.empty?
      total_rev = 0.0
      total_cost = 0.0
      TrainingClass.where(id: class_ids).includes(:class_expenses).find_each do |tc|
        tc_rev = tc.attendees.attendees.where(payment_status: "Paid").sum { |a| (a.total_final_price || 0).to_f }
        tc_cost = (tc.cost.to_f + tc.class_expenses.sum(:amount).to_f)
        total_rev += tc_rev
        total_cost += tc_cost
      end
      margin = total_rev - total_cost
      pct = total_rev.positive? ? (margin / total_rev * 100).round(1) : 0
      { margin_thb: margin.round(2), margin_pct: pct, revenue: total_rev, cost: total_cost, na_reason: nil }
    end

    def build_kpis(rev:, prev_rev:, paid:, prev_paid:, avg_price:, prev_avg:, cvr:, prev_cvr:, repeat_pct:, prev_repeat:, margin_data:, trend:)
      spark_rev = trend.map { |r| r[:revenue].to_f }
      spark_paid = trend.map { |r| r[:paid].to_i }
      spark_avg = trend.map { |r| r[:paid].positive? ? (r[:revenue].to_f / r[:paid]) : 0 }
      spark_cvr = trend.map { |r| r[:registered].positive? ? (r[:paid].to_f / r[:registered] * 100) : 0 }
      delta_rev = prev_rev.positive? ? ((rev - prev_rev) / prev_rev * 100).round(1) : nil
      delta_paid = prev_paid.positive? ? ((paid - prev_paid).to_f / prev_paid * 100).round(1) : nil
      delta_avg = prev_avg.positive? ? ((avg_price - prev_avg) / prev_avg * 100).round(1) : nil
      delta_cvr = prev_cvr ? (cvr - prev_cvr).round(1) : nil
      delta_repeat = prev_repeat ? (repeat_pct - prev_repeat).round(1) : nil
      [
        { key: "revenue", label: "Revenue (THB)", value: rev.round(2), delta: delta_rev, delta_label: delta_rev.nil? ? nil : (delta_rev >= 0 ? "+#{delta_rev}%" : "#{delta_rev}%"), sparkline: spark_rev },
        { key: "paid_orders", label: "Paid orders", value: paid, delta: delta_paid, delta_label: delta_paid.nil? ? nil : (delta_paid >= 0 ? "+#{delta_paid}%" : "#{delta_paid}%"), sparkline: spark_paid },
        { key: "avg_price_per_head", label: "Avg price/head (THB)", value: avg_price, delta: delta_avg, delta_label: delta_avg.nil? ? nil : (delta_avg >= 0 ? "+#{delta_avg}%" : "#{delta_avg}%"), sparkline: spark_avg },
        { key: "cvr", label: "CVR Lead→Paid (%)", value: cvr, delta: delta_cvr, delta_label: delta_cvr.nil? ? nil : (delta_cvr >= 0 ? "+#{delta_cvr}pp" : "#{delta_cvr}pp"), sparkline: spark_cvr },
        { key: "repeat_rate", label: "Repeat rate (%)", value: repeat_pct, delta: delta_repeat, delta_label: delta_repeat.nil? ? nil : (delta_repeat >= 0 ? "+#{delta_repeat}pp" : "#{delta_repeat}pp"), sparkline: [] },
        { key: "gross_margin", label: "Gross margin", value_thb: margin_data[:margin_thb], value_pct: margin_data[:margin_pct], delta: nil, delta_label: nil, sparkline: [], na_reason: margin_data[:na_reason] }
      ]
    end

    def executive_summary_text(period_label:, revenue:, paid:, cvr:, repeat_pct:)
      "#{period_label}: รายได้ #{number_to_thb_short(revenue)} · ใบชำระ #{paid} · CVR #{cvr}% · Repeat #{repeat_pct}%"
    end

    def number_to_thb_short(n)
      return "฿0" if n.to_f.zero?
      k = (n.to_f / 1000).round(1)
      k >= 1000 ? "฿#{(k / 1000).round(1)}M" : "฿#{k}k"
    end

    def best_selling_courses_with_sparklines(trend)
      by_course = attendees.group_by { |a| a.training_class.title }
      courses_data = by_course.map do |title, list|
        paid = list.count { |a| a.payment_status == "Paid" }
        rev = list.sum { |a| a.payment_status == "Paid" ? (a.total_final_price || 0).to_f : 0 }
        avg = paid.positive? ? (rev / paid).round(2) : 0
        cvr = list.any? ? (paid.to_f / list.size * 100).round(1) : 0
        spark = (range.begin.to_date..range.end.to_date).map { |d| list.select { |a| a.training_class.date == d && a.payment_status == "Paid" }.sum { |a| (a.total_final_price || 0).to_f } }
        { course: title, revenue: rev.round(2), paid: paid, avg_price_head: avg, cvr: cvr, sparkline: spark }
      end
      { by_revenue: courses_data.sort_by { |h| -h[:revenue] }.first(15), by_paid: courses_data.sort_by { |h| -h[:paid] }.first(15), by_cvr: courses_data.select { |h| h[:paid] >= 1 }.sort_by { |h| -h[:cvr] }.first(15) }
    end

    def pricing_insights_data(trend)
      avg_trend = trend.map { |r| { date: r[:date], label: r[:label], avg_price_per_head: r[:paid].positive? ? (r[:revenue].to_f / r[:paid]).round(2) : 0 } }
      amounts = attendees.select { |a| a.payment_status == "Paid" }.map { |a| (a.total_final_price || 0).to_f }
      distribution = PRICE_BUCKETS.map do |lo, hi, label|
        count = hi.nil? ? amounts.count { |x| x >= lo } : amounts.count { |x| x >= lo && x < hi }
        { bucket: label, count: count }
      end
      { avg_price_trend: avg_trend, distribution: distribution }
    end

    def channel_performance_data
      by_channel = attendees.group_by { |a| a.source_channel.presence || "อื่นๆ" }
      rows = by_channel.map do |ch, list|
        paid = list.count { |a| a.payment_status == "Paid" }
        rev = list.sum { |a| a.payment_status == "Paid" ? (a.total_final_price || 0).to_f : 0 }
        avg = paid.positive? ? (rev / paid).round(2) : 0
        cvr = list.any? ? (paid.to_f / list.size * 100).round(1) : 0
        { channel: ch, leads: list.size, paid: paid, revenue: rev.round(2), avg_price_head: avg, cvr: cvr }
      end
      { sort_by: "revenue", rows: rows.sort_by { |h| -h[:revenue] } }
    end

    def returning_revenue_pct
      customer_ids = attendees.map(&:customer_id).compact.uniq
      return 0 if customer_ids.empty?
      repeat_customer_ids = customer_ids.select { |cid| Attendee.attendees.where(customer_id: cid).count > 1 }
      total_rev = revenue_from(attendees)
      return 0 if total_rev.zero?
      repeat_rev = attendees.select { |a| a.payment_status == "Paid" && repeat_customer_ids.include?(a.customer_id) }.sum { |a| (a.total_final_price || 0).to_f }
      (repeat_rev / total_rev * 100).round(1)
    end
  end
end

# === How to wire data if your model names differ ===
# - Lead: This app has no Lead model; funnel "lead" is 0. To add leads, inject a scope/model and set funnel_counts[:lead].
# - Registered/Paid/Attended: From Attendee (scope :attendees, payment_status, attendance_status). If you use Registration + Payment + Attendance, aggregate from those.
# - Channel: Attendee.source_channel. If channel is on Customer (e.g. acquisition_channel), join and use that.
# - Course: Currently grouped by training_class.title. When training_classes.course_id exists, use Course and filter by course_id.
# - Top spenders / Repeat learners: Use customer_id on Attendee and Customer model. Replace Customer.find_by with your User/Company if needed.
# - Cohort heatmap: first purchase = min(training_classes.date) per customer_id. Adjust if "first purchase" is defined elsewhere.
