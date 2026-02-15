# frozen_string_literal: true

module Insights
  # Growth & optimization: new clients, conversion, promo revenue, LTV, repeat rate.
  # Funnel (lead → potential → enrolled), acquisition trend, revenue by promotion, underperforming promos.
  class StrategyInsights
    CACHE_TTL = 5.minutes
    UNDERPERFORM_THRESHOLD_REVENUE_PCT = 5.0  # below 5% of total promo revenue
    UNDERPERFORM_CONVERSION_MIN = 10          # or conversion count below 10

    def initialize(params = {})
      @resolver = DateRangeResolver.new(params)
      @params = params
    end

    def call
      Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
        promo_query = PromotionPerformanceQuery.new(promo_params)
        {
          kpis: kpis(promo_query),
          chart_data: {
            funnel: funnel_data,
            client_acquisition_trend: client_acquisition_trend,
            revenue_by_promotion: promo_query.revenue_share
          },
          promotion_leaderboard: promo_query.leaderboard_rows,
          underperforming_promotions: underperforming_promotions(promo_query)
        }
      end.merge(date_range: { start_date: @resolver.start_date, end_date: @resolver.end_date, preset: @resolver.preset })
    end

    private

    def cache_key
      ["insights/strategy", @resolver.start_date, @resolver.end_date].join("/")
    end

    def range
      @resolver.range
    end

    def promo_params
      period = case @resolver.preset
               when "ytd" then "ytd"
               when "custom" then "custom"
               else "this_month"
               end
      {
        period: period,
        date_from: range.begin.to_s,
        date_to: range.end.to_s
      }
    end

    def kpis(promo_query)
      pk = promo_query.kpis
      # New clients MTD = distinct customers with first attendee in period (simplified: new emails in period)
      new_clients_mtd = Attendee.attendees.joins(:training_class)
        .where("training_classes.date >= ? AND training_classes.date <= ?", range.begin, range.end)
        .distinct.count(:customer_id)
      # Conversion: enrolled / (leads + enrolled) in period
      leads = Attendee.where(status: "potential").joins(:training_class)
        .where("training_classes.date >= ? AND training_classes.date <= ?", range.begin, range.end).count
      enrolled = Attendee.attendees.joins(:training_class)
        .where("training_classes.date >= ? AND training_classes.date <= ?", range.begin, range.end).count
      total_lead_funnel = leads + enrolled
      conversion_rate = total_lead_funnel.positive? ? ((enrolled.to_f / total_lead_funnel) * 100).round(1) : 0
      campaign_revenue = pk[:promo_revenue].to_f.round(2)
      total_rev = Attendee.attendees.joins(:training_class)
        .where("training_classes.date >= ? AND training_classes.date <= ?", range.begin, range.end)
        .sum(:total_amount).to_f
      client_count = Attendee.attendees.joins(:training_class)
        .where("training_classes.date >= ? AND training_classes.date <= ?", range.begin, range.end)
        .distinct.count(:customer_id)
      avg_revenue_per_client = client_count.positive? ? (total_rev / client_count).round(2) : 0
      # LTV estimated: avg revenue per client * 1.5 (placeholder multiplier)
      ltv_estimated = (avg_revenue_per_client * 1.5).round(2)
      # Repeat rate: customers with >1 registration in period or ever
      repeat_count = Customer.joins(:attendees).where(attendees: { status: [nil, "attendee"] })
        .group("customers.id").having("COUNT(attendees.id) > 1").count.size
      total_customers = Customer.joins(:attendees).where(attendees: { status: [nil, "attendee"] }).distinct.count
      repeat_rate = total_customers.positive? ? ((repeat_count.to_f / total_customers) * 100).round(1) : 0

      {
        new_clients_mtd: new_clients_mtd,
        conversion_rate: conversion_rate,
        campaign_promo_revenue: campaign_revenue,
        avg_revenue_per_client: avg_revenue_per_client,
        ltv_estimated: ltv_estimated,
        repeat_rate: repeat_rate
      }
    end

    def funnel_data
      leads = Attendee.where(status: "potential").joins(:training_class)
        .where("training_classes.date >= ? AND training_classes.date <= ?", range.begin, range.end).count
      enrolled = Attendee.attendees.joins(:training_class)
        .where("training_classes.date >= ? AND training_classes.date <= ?", range.begin, range.end).count
      # "Lead" = potential, "Enrolled" = attendee
      [
        { stage: "Lead", count: leads },
        { stage: "Potential", count: leads },
        { stage: "Enrolled", count: enrolled }
      ]
    end

    def client_acquisition_trend
      by_month = Attendee.attendees.joins(:training_class)
        .where("training_classes.date >= ? AND training_classes.date <= ?", range.begin, range.end)
        .group("strftime('%Y-%m', training_classes.date)")
        .distinct.count(:customer_id)
      months = (range.begin.to_date.beginning_of_month..range.end.to_date.end_of_month).select { |d| d == d.beginning_of_month }
      months.map { |m| { label: m.strftime("%b %Y"), value: by_month[m.strftime("%Y-%m")].to_i } }
    end

    def underperforming_promotions(promo_query)
      rows = promo_query.leaderboard_rows
      total = rows.sum { |r| r[:revenue].to_f }
      return [] if total.zero?
      rows.select do |r|
        rev_pct = total.positive? ? ((r[:revenue].to_f / total) * 100) : 0
        (rev_pct < UNDERPERFORM_THRESHOLD_REVENUE_PCT && r[:revenue].to_f.positive?) ||
          (r[:impact_tag].to_s == "Underperforming")
      end.map { |r| { id: r[:id], name: r[:name], revenue: r[:revenue], revenue_share_pct: total.positive? ? ((r[:revenue].to_f / total) * 100).round(1) : 0 } }
    end
  end
end
