# frozen_string_literal: true

module Clients
  # Commercial intelligence: top spenders, channels, segment mix, concentration, risk lists.
  class ClientAnalysis
    CACHE_TTL = 5.minutes
    NO_ACTIVITY_DAYS = 90

    def initialize(params = {})
      @resolver = Clients::DateRangeResolver.new(params)
      @params = params
    end

    def call
      Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
        {
          kpis: kpis,
          top_spenders: top_spenders,
          revenue_concentration: revenue_concentration,
          revenue_by_channel: revenue_by_channel,
          conversion_by_channel: conversion_by_channel,
          segment_mix: segment_mix,
          risk_outstanding: risk_outstanding,
          risk_no_activity: risk_no_activity
        }
      end.merge(date_range: { start_date: @resolver.start_date, end_date: @resolver.end_date, preset: @resolver.preset })
    end

    private

    def cache_key
      ["clients/analysis", @resolver.start_date, @resolver.end_date, @params[:client_type], @params[:channel], @params[:min_revenue]].join("/")
    end

    def range
      @resolver.range
    end

    def attendees_scope
      @attendees_scope ||= Attendee.attendees
        .joins(:training_class, :customer)
        .where("training_classes.date >= ? AND training_classes.date <= ?", range.begin, range.end)
        .includes(:customer, :training_class)
    end

    def attendees_in_range
      @attendees_in_range ||= apply_client_type(attendees_scope).to_a
    end

    def apply_client_type(scope)
      case @params[:client_type]
      when "corporate", "Corp" then scope.corp
      when "individual", "Indi" then scope.indi
      else scope
      end
    end

    def all_customers_with_revenue
      @all_customers ||= begin
        scope = Customer.joins(:attendees).where(attendees: { status: [nil, "attendee"] }).distinct
        scope = scope.where(attendees: { participant_type: "Corp" }) if @params[:client_type].to_s.downcase == "corporate"
        scope = scope.where(attendees: { participant_type: "Indi" }) if @params[:client_type].to_s.downcase == "individual"
        scope = scope.where(acquisition_channel: @params[:channel]) if @params[:channel].present?
        scope
      end
    end

    def kpis
      customers_in_range = attendees_in_range.map(&:customer_id).compact.uniq
      total_clients = all_customers_with_revenue.count
      active = customers_in_range.size
      new_clients = Customer.where(id: customers_in_range).where("created_at >= ?", range.begin).count
      total_rev = attendees_in_range.select { |a| a.payment_status == "Paid" }.sum(&:total_final_price).to_f
      avg_rev = active.positive? ? (total_rev / active).round(2) : 0
      repeat_count = Customer.joins(:attendees).where(attendees: { status: [nil, "attendee"] }).group("customers.id").having("COUNT(attendees.id) > 1").count.size
      repeat_rate = total_clients.positive? ? ((repeat_count.to_f / total_clients) * 100).round(1) : 0
      corp_rev = Attendee.attendees.corp.joins(:training_class).where("training_classes.date >= ? AND training_classes.date <= ?", range.begin, range.end).select { |a| a.payment_status == "Paid" }.sum(&:total_final_price).to_f
      corp_pct = total_rev.positive? ? ((corp_rev / total_rev) * 100).round(1) : 0

      {
        total_clients: total_clients,
        active_clients: active,
        new_clients: new_clients,
        avg_revenue_per_client: avg_rev,
        repeat_rate: repeat_rate,
        corporate_pct_revenue: corp_pct
      }
    end

    def top_spenders
      by_customer = attendees_in_range
        .select { |a| a.payment_status == "Paid" }
        .group_by(&:customer_id)
        .transform_values { |list| list.sum(&:total_final_price).round(2) }
      by_customer = by_customer.select { |_, v| v >= @params[:min_revenue].to_f } if @params[:min_revenue].present?
      top = by_customer.sort_by { |_, v| -v }.first(10)
      customer_ids = top.map(&:first).compact
      customers = Customer.where(id: customer_ids).index_by(&:id)
      top.map do |cid, rev|
        c = customers[cid]
        net = attendees_in_range.select { |a| a.customer_id == cid }.sum(&:total_price_before_vat)
        cost = attendees_in_range.select { |a| a.customer_id == cid }.map { |a| a.training_class.total_cost }.sum
        profit = (net - cost).round(2)
        last_act = attendees_in_range.select { |a| a.customer_id == cid }.map { |a| a.training_class.date }.max
        type = attendees_in_range.any? { |a| a.customer_id == cid && a.participant_type == "Corp" } ? "Corporate" : "Individual"
        channel = c&.respond_to?(:acquisition_channel) && c.acquisition_channel.presence ? c.acquisition_channel : "unknown"
        { customer_id: cid, name: c&.company_name.presence || c&.name || "—", revenue: rev, profit: profit, last_activity: last_act, client_type: type, channel: channel }
      end
    end

    def revenue_concentration
      by_customer = attendees_in_range.select { |a| a.payment_status == "Paid" }.group_by(&:customer_id).transform_values { |l| l.sum(&:total_final_price) }
      sorted = by_customer.values.sort_by { |v| -v }
      total = sorted.sum.round(2)
      return { top_10_pct: 0, top_20_pct: 0, top_50_pct: 0 } if total.zero?
      n = sorted.size
      top_10 = sorted.first([(n * 0.1).ceil, 1].max).sum
      top_20 = sorted.first([(n * 0.2).ceil, 1].max).sum
      top_50 = sorted.first([(n * 0.5).ceil, 1].max).sum
      {
        top_10_pct: ((top_10 / total) * 100).round(1),
        top_20_pct: ((top_20 / total) * 100).round(1),
        top_50_pct: ((top_50 / total) * 100).round(1)
      }
    end

    def revenue_by_channel
      list = attendees_in_range.select { |a| a.payment_status == "Paid" }
      channel_attr = Customer.column_names.include?("acquisition_channel") ? :acquisition_channel : nil
      by_channel = list.group_by do |a|
        if channel_attr && a.customer
          a.customer.send(channel_attr).presence || a.source_channel.presence || "unknown"
        else
          a.source_channel.presence || "unknown"
        end
      end
      by_channel.transform_values! { |l| l.sum(&:total_final_price).round(2) }.sort_by { |_, v| -v }
    end

    def conversion_by_channel
      # Leads (potential) → Enrolled by channel
      scope = Attendee.joins(:training_class).where("training_classes.date >= ? AND training_classes.date <= ?", range.begin, range.end)
      leads = scope.where(status: "potential").group(:source_channel).count
      enrolled = scope.attendees.group(:source_channel).count
      channels = (leads.keys + enrolled.keys).uniq
      channels.map do |ch|
        l = leads[ch].to_i
        e = enrolled[ch].to_i
        conv = (l + e).positive? ? ((e.to_f / (l + e)) * 100).round(1) : 0
        { channel: ch.presence || "unknown", leads: l, enrolled: e, conversion_pct: conv }
      end.sort_by { |h| -h[:enrolled] }
    end

    def segment_mix
      corp_rev = attendees_in_range.select { |a| a.participant_type == "Corp" && a.payment_status == "Paid" }.sum(&:total_final_price).round(2)
      indi_rev = attendees_in_range.select { |a| a.participant_type != "Corp" && a.payment_status == "Paid" }.sum(&:total_final_price).round(2)
      total = corp_rev + indi_rev
      one_time = Customer.joins(:attendees).where(attendees: { status: [nil, "attendee"] }).group("customers.id").having("COUNT(attendees.id) = 1").count.size
      repeat = Customer.joins(:attendees).where(attendees: { status: [nil, "attendee"] }).group("customers.id").having("COUNT(attendees.id) > 1").count.size
      new_in_period = attendees_in_range.map(&:customer_id).uniq.count { |cid| Customer.find_by(id: cid)&.created_at&.>= range.begin }
      returning = attendees_in_range.map(&:customer_id).compact.uniq.size - new_in_period

      {
        corporate_vs_individual: { corporate: corp_rev, individual: indi_rev, total: total },
        one_time_vs_repeat: { one_time: one_time, repeat: repeat },
        new_vs_returning: { new: new_in_period, returning: [returning, 0].max }
      }
    end

    def risk_outstanding
      Attendee.attendees
        .joins(:customer, :training_class)
        .where(payment_status: "Pending")
        .where("attendees.due_date IS NOT NULL AND attendees.due_date < ?", Date.current)
        .includes(:customer, :training_class)
        .sort_by { |a| -a.total_final_price }
        .first(20)
        .map { |a| { customer: a.customer&.company_name.presence || a.name, amount: a.total_final_price, due_date: a.due_date } }
    end

    def risk_no_activity
      last_activity = Attendee.attendees
        .joins(:training_class)
        .group(:customer_id)
        .maximum("training_classes.date")
      high_value = Attendee.attendees
        .where(payment_status: "Paid")
        .group(:customer_id)
        .sum(:total_amount)
      cutoff = Date.current - NO_ACTIVITY_DAYS.days
      at_risk = last_activity.select { |cid, date| date && date < cutoff && (high_value[cid].to_f >= 10_000) }.to_a
      at_risk.first(20).map do |customer_id, date|
        c = Customer.find_by(id: customer_id)
        { customer: c&.company_name.presence || c&.name || "—", last_activity: date, revenue: high_value[customer_id].to_f.round(2) }
      end
    end
  end
end
