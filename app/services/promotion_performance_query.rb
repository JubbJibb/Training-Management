# frozen_string_literal: true

# Marketing-oriented promotion analytics. Accepts filter params and returns
# KPIs (with previous-period deltas), revenue share for donut, leaderboard,
# insights, and drilldown data per promotion.
# Uses Attendee + AttendeePromotion + TrainingClass (no PromotionUsage table).
#
# Chart data (revenue_share) is consumed by the donut chart (Chart.js):
#   { "labels": ["Promo A", "Promo B"], "values": [1000, 500], "total": 1500 }
# Drilldown time_series for the line chart:
#   [{ "date": "2025-02-01", "revenue": 500, "discount": 50 }, ...]
class PromotionPerformanceQuery
  PERIODS = { "this_month" => :this_month, "last_month" => :last_month, "ytd" => :ytd, "custom" => :custom }.freeze

  def initialize(params = {})
    @params = params
    @current_range = date_range_for(:current)
    @previous_range = date_range_for(:previous)
  end

  def kpis
    cur = kpi_for_range(@current_range)
    prev = kpi_for_range(@previous_range)
    leaderboard = leaderboard_rows
    cur.merge(
      previous_promo_revenue: prev[:promo_revenue],
      previous_seats: prev[:seats],
      previous_total_discount: prev[:total_discount],
      previous_avg_margin: prev[:avg_margin],
      best_promo_name: leaderboard.first&.dig(:name)
    )
  end

  def revenue_share
    rows = leaderboard_rows
    total = rows.sum { |r| r[:revenue].to_f }
    return { labels: [], values: [], total: 0 } if total.zero?

    {
      labels: rows.map { |r| r[:name] },
      values: rows.map { |r| r[:revenue].to_f.round(2) },
      total: total.round(2)
    }
  end

  def leaderboard_rows
    @leaderboard_rows ||= build_leaderboard
  end

  def insights
    @insights ||= build_insights
  end

  def drilldown(promotion_id)
    promo = Promotion.find_by(id: promotion_id)
    return {} unless promo

    range = @current_range
    attendee_ids = AttendeePromotion.where(promotion_id: promo.id)
                                    .joins(attendee: :training_class)
                                    .where("training_classes.date >= ? AND training_classes.date <= ?", range.begin, range.end)
                                    .pluck(:attendee_id)
                                    .uniq
    attendees = Attendee.where(id: attendee_ids).includes(:training_class)

    by_segment = attendees.group_by(&:participant_type).transform_values { |list| list.sum(&:total_final_price).round(2) }
    by_channel = attendees.group_by { |a| a.source_channel.presence || "—" }.transform_values { |list| list.sum(&:total_final_price).round(2) }

    # Time series: by date (revenue + discount per day)
    by_date = attendees.group_by { |a| a.training_class.date }
                       .transform_values do |list|
                         rev = list.sum(&:total_final_price)
                         disc = list.sum { |a| promo.calculate_discount(a.base_price) * (a.seats || 1) }
                         { revenue: rev.round(2), discount: disc.round(2) }
                       end

    {
      promotion: promo,
      by_segment: by_segment,
      by_channel: by_channel,
      time_series: by_date.sort_by { |d, _| d }.map { |date, h| { date: date.to_s, revenue: h[:revenue], discount: h[:discount] } }
    }
  end

  def filter_chips
    chips = []
    chips << period_label
    chips << "Course: #{TrainingClass.find_by(id: @params[:course_id])&.title}" if @params[:course_id].present?
    chips << "Segment: #{@params[:segment]}" if @params[:segment].present? && @params[:segment] != "all"
    chips << "Channel: #{@params[:channel]}" if @params[:channel].present?
    chips << "Payment: #{@params[:payment_status]}" if @params[:payment_status].present?
    chips
  end

  def period_label
    case @params[:period].to_s
    when "last_month" then "Last month"
    when "ytd" then "YTD"
    when "custom" then [@current_range.begin, @current_range.end].map { |d| d.strftime("%d %b") }.join(" – ")
    else "This month"
    end
  end

  private

  def date_range_for(which)
    case which
    when :current
      range_from_params(@params[:period], @params[:date_from], @params[:date_to])
    when :previous
      range_previous(@params[:period], @params[:date_from], @params[:date_to])
    end
  end

  def range_from_params(period, date_from, date_to)
    case period.to_s
    when "this_month"
      Date.current.beginning_of_month..Date.current.end_of_month
    when "last_month"
      d = Date.current.last_month
      d.beginning_of_month..d.end_of_month
    when "ytd"
      Date.current.beginning_of_year..Date.current
    when "custom"
      from = date_from.present? ? Date.parse(date_from.to_s) : Date.current.beginning_of_month
      to = date_to.present? ? Date.parse(date_to.to_s) : Date.current.end_of_month
      from..to
    else
      Date.current.beginning_of_month..Date.current.end_of_month
    end
  rescue ArgumentError
    Date.current.beginning_of_month..Date.current.end_of_month
  end

  def range_previous(period, date_from, date_to)
    case period.to_s
    when "this_month"
      d = Date.current.last_month
      d.beginning_of_month..d.end_of_month
    when "last_month"
      d = Date.current.last_month - 1.month
      d.beginning_of_month..d.end_of_month
    when "ytd"
      Date.current.beginning_of_year - 1.year..Date.current - 1.year
    when "custom"
      from = date_from.present? ? Date.parse(date_from.to_s) : Date.current.beginning_of_month
      to = date_to.present? ? Date.parse(date_to.to_s) : Date.current.end_of_month
      len = (to - from).to_i + 1
      (from - len.days)..(to - len.days)
    else
      d = Date.current.last_month
      d.beginning_of_month..d.end_of_month
    end
  rescue ArgumentError
    d = Date.current.last_month
    d.beginning_of_month..d.end_of_month
  end

  def base_scope(range)
    scope = Attendee.attendees
                    .joins(:training_class, :attendee_promotions)
                    .where("training_classes.date >= ? AND training_classes.date <= ?", range.begin, range.end)
    scope = scope.where(training_class_id: @params[:course_id]) if @params[:course_id].present?
    scope = scope.where(participant_type: @params[:segment]) if @params[:segment].present? && %w[Indi Corp].include?(@params[:segment])
    scope = scope.where(source_channel: @params[:channel]) if @params[:channel].present?
    scope = scope.where(payment_status: @params[:payment_status]) if @params[:payment_status].present?
    scope
  end

  def kpi_for_range(range)
    scope = base_scope(range).select("DISTINCT attendees.id")
    attendee_ids = scope.pluck(:id)
    return { promo_revenue: 0, seats: 0, total_discount: 0, avg_margin: 0 } if attendee_ids.empty?

    # Use SQL aggregates to avoid loading all records
    base = Attendee.where(id: attendee_ids)
    promo_revenue = base.sum(:total_amount).to_f.round(2)
    seats = base.sum(:seats).to_i
    # Discount requires per-attendee promotion logic; load once with includes to avoid N+1
    attendees = Attendee.where(id: attendee_ids).includes(:promotions)
    total_discount = attendees.sum do |a|
      a.promotions.select(&:active?).sum { |p| p.calculate_discount(a.base_price) * (a.seats || 1) }
    end.round(2)
    avg_margin = promo_revenue.positive? ? (((promo_revenue - total_discount) / promo_revenue) * 100).round(1) : 0

    {
      promo_revenue: promo_revenue,
      seats: seats,
      total_discount: total_discount,
      avg_margin: avg_margin
    }
  end

  def build_leaderboard
    range = @current_range
    promotions = Promotion.order(:name).to_a
    result = []

    promotions.each do |promo|
      ids = attendee_ids_for_promo(promo.id, range)
      next result << empty_leaderboard_row(promo) if ids.empty?

      # Use SQL sum for revenue and seats; load attendees with training_class only for discount (base_price)
      base = Attendee.where(id: ids)
      revenue = base.sum(:total_amount).to_f.round(2)
      seats = base.sum(:seats).to_i
      attendees = base.includes(:training_class)
      discount_cost = attendees.sum { |a| promo.calculate_discount(a.base_price) * (a.seats || 1) }.round(2)
      margin_pct = revenue.positive? ? (((revenue - discount_cost) / revenue) * 100).round(1) : 0
      gross = attendees.sum { |a| a.base_price * (a.seats || 1) }.round(2)
      discount_pct = gross.positive? ? ((discount_cost / gross) * 100).round(0) : 0
      impact_tag = impact_tag_for(revenue: revenue, margin_pct: margin_pct, seats: seats, discount_cost: discount_cost)

      result << {
        id: promo.id,
        name: promo.name,
        type: promo.discount_type,
        type_label: promo.discount_type.humanize,
        revenue: revenue,
        seats: seats,
        margin_pct: margin_pct,
        discount_cost: discount_cost,
        discount_pct: discount_pct,
        impact_tag: impact_tag
      }
    end

    result.sort_by { |r| -r[:revenue].to_f }
  end

  def attendee_ids_for_promo(promotion_id, range)
    scope = AttendeePromotion.where(promotion_id: promotion_id)
                             .joins(attendee: :training_class)
                             .where("training_classes.date >= ? AND training_classes.date <= ?", range.begin, range.end)
    scope = scope.where(attendees: { training_class_id: @params[:course_id] }) if @params[:course_id].present?
    scope = scope.where(attendees: { participant_type: @params[:segment] }) if @params[:segment].present? && %w[Indi Corp].include?(@params[:segment])
    scope = scope.where(attendees: { source_channel: @params[:channel] }) if @params[:channel].present?
    scope = scope.where(attendees: { payment_status: @params[:payment_status] }) if @params[:payment_status].present?
    scope.distinct.pluck(:attendee_id)
  end

  def empty_leaderboard_row(promo)
    {
      id: promo.id,
      name: promo.name,
      type: promo.discount_type,
      type_label: promo.discount_type.humanize,
      revenue: 0,
      seats: 0,
      margin_pct: 0,
      discount_cost: 0,
      discount_pct: 0,
      impact_tag: "Underperforming"
    }
  end

  def impact_tag_for(revenue:, margin_pct:, seats:, discount_cost:)
    return "Underperforming" if revenue.zero?
    return "High Volume" if seats >= 20 && revenue > 0
    return "High Margin" if margin_pct >= 70
    return "Underperforming" if margin_pct < 40 && revenue < 10_000

    "Standard"
  end

  def build_insights
    list = []
    rows = leaderboard_rows
    total_rev = rows.sum { |r| r[:revenue].to_f }
    total_disc = rows.sum { |r| r[:discount_cost].to_f }
    total_gross = rows.sum { |r| r[:revenue].to_f + (rows.find { |x| x[:name] == r[:name] } ? 0 : 0) }
    gross_approx = total_rev + total_disc

    if total_rev.positive?
      top = rows.max_by { |r| r[:revenue].to_f }
      pct = ((top[:revenue].to_f / total_rev) * 100).round(0)
      list << "#{top[:name]} drives #{pct}% of promo revenue."
    end

    pct_promos = rows.select { |r| r[:type].to_s == "percentage" }
    bxgy_promos = rows.select { |r| r[:type].to_s == "buy_x_get_y" }
    if pct_promos.any? && bxgy_promos.any?
      avg_pct = pct_promos.sum { |r| r[:margin_pct].to_f } / pct_promos.size
      avg_bxgy = bxgy_promos.sum { |r| r[:margin_pct].to_f } / bxgy_promos.size
      list << "Percentage promos avg margin: #{avg_pct.round(0)}% vs Buy X Pay Y: #{avg_bxgy.round(0)}%."
    end

    if gross_approx.positive?
      leak = (total_disc / gross_approx * 100).round(0)
      list << "Discount leakage: #{leak}% of gross (฿#{total_disc.round(0)})."
    end

    under = rows.select { |r| r[:revenue].to_f.zero? }
    list << "#{under.size} promotion(s) with 0 usage in period." if under.any?

    list
  end
end
