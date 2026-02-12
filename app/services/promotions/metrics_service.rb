# frozen_string_literal: true

module Promotions
  # Computes promotion KPIs and performance for the Promotion Management page.
  # Uses AttendeePromotion + Attendee + TrainingClass; no new DB columns.
  class MetricsService
    def initialize(period: :this_month)
      @period = period
      @start = period_start
      @end = period_end
    end

    def kpi_strip
      {
        active_count: Promotion.active.count,
        seats_using_promo: seats_using_promo_total,
        total_discount_thb: total_discount_given.round(2),
        avg_discount_pct: avg_discount_pct.round(1),
        revenue_from_promotions: revenue_from_promotions.round(2),
        margin_impact_pct: margin_impact_pct.round(1)
      }
    end

    def performance_rows
      Promotion.order(:name).map { |p| row_for(p) }
    end

    def highlights
      rows = performance_rows.reject { |r| r[:used_seats].to_i.zero? }
      return {} if rows.empty?

      most_revenue = rows.max_by { |r| r[:revenue_generated].to_f }
      highest_conv = rows.max_by { |r| r[:conversion_rate].to_f }
      worst_margin = rows.min_by { |r| r[:margin_impact_pct].to_f }
      {
        most_revenue_promo: most_revenue&.dig(:name),
        highest_conversion_promo: highest_conv&.dig(:name),
        worst_margin_promo: worst_margin&.dig(:name)
      }
    end

    def insights
      list = []
      rows = performance_rows.reject { |r| r[:used_seats].to_i.zero? }
      return list if rows.empty?

      # Sample insight: compare percentage vs buy_x_get_y margin
      pct_promos = rows.select { |r| r[:type] == "percentage" }
      bxgy_promos = rows.select { |r| r[:type] == "buy_x_get_y" }
      if pct_promos.any? && bxgy_promos.any?
        avg_pct = pct_promos.sum { |r| r[:margin_impact_pct].to_f } / pct_promos.size
        avg_bxgy = bxgy_promos.sum { |r| r[:margin_impact_pct].to_f } / bxgy_promos.size
        list << "Percentage promos avg margin impact: #{avg_pct.round(0)}% vs Buy X Pay Y: #{avg_bxgy.round(0)}%."
      end
      top = rows.max_by { |r| r[:revenue_generated].to_f }
      list << "#{top[:name]} drives ฿#{top[:revenue_generated].to_f.round(0)} revenue from promotions." if top
      list << "Total discount given this period: ฿#{total_discount_given.round(0)} across #{seats_using_promo_total} seats."
      list
    end

    private

    def period_start
      case @period
      when :this_month then Date.current.beginning_of_month
      when :last_month then Date.current.last_month.beginning_of_month
      else Date.current.beginning_of_month
      end
    end

    def period_end
      case @period
      when :this_month then Date.current.end_of_month
      when :last_month then Date.current.last_month.end_of_month
      else Date.current.end_of_month
      end
    end

    def base_attendees_with_promo
      Attendee.attendees
              .joins(:training_class, :attendee_promotions)
              .where("training_classes.date >= ? AND training_classes.date <= ?", @start, @end)
    end

    def seats_using_promo_total
      base_attendees_with_promo.sum(:seats)
    end

    def total_discount_given
      base_attendees_with_promo.sum do |a|
        a.promotions.where(active: true).sum { |p| p.calculate_discount(a.base_price) * (a.seats || 1) }
      end
    end

    def revenue_from_promotions
      base_attendees_with_promo.sum(&:total_final_price)
    end

    def avg_discount_pct
      atts = base_attendees_with_promo.includes(:promotions)
      return 0 if atts.empty?
      total_pct = 0
      count = 0
      atts.each do |a|
        base = a.base_price * (a.seats || 1)
        next if base.zero?
        disc = a.total_discount_amount * (a.seats || 1)
        total_pct += (disc / base * 100)
        count += 1
      end
      count.positive? ? total_pct / count : 0
    end

    def margin_impact_pct
      rev = revenue_from_promotions
      return 0 if rev.zero?
      discount = total_discount_given
      ((rev - discount) / rev * 100)
    end

    def row_for(promotion)
      attendee_ids = AttendeePromotion.where(promotion_id: promotion.id)
                                      .joins(attendee: :training_class)
                                      .where("training_classes.date >= ? AND training_classes.date <= ?", @start, @end)
                                      .pluck(:attendee_id)
                                      .uniq
      attendees = Attendee.where(id: attendee_ids)

      used_seats = attendees.sum(:seats)
      revenue = attendees.sum(&:total_final_price)
      discount_cost = attendees.sum do |a|
        promotion.calculate_discount(a.base_price) * (a.seats || 1)
      end
      avg_per_seat = used_seats.positive? ? (revenue / used_seats).round(2) : 0
      conversion_rate = 0
      margin_pct = revenue.positive? ? ((revenue - discount_cost) / revenue * 100).round(1) : 0

      {
        id: promotion.id,
        name: promotion.name,
        type: promotion.discount_type,
        type_label: promotion.discount_type.humanize,
        discount_logic: promotion.discount_description,
        used_seats: used_seats,
        revenue_generated: revenue.round(2),
        total_discount_cost: discount_cost.round(2),
        avg_price_per_seat: avg_per_seat,
        conversion_rate: conversion_rate,
        margin_impact_pct: margin_pct
      }
    end
  end
end
