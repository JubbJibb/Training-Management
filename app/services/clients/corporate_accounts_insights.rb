# frozen_string_literal: true

module Clients
  # Account-based view for corporate clients: KPIs, accounts table, at-risk panel.
  # Corporate account = group by company name (from customer); id = representative customer_id.
  class CorporateAccountsInsights
    CACHE_TTL = 5.minutes
    AT_RISK_NO_ACTIVITY_DAYS = 90
    WATCH_NO_ACTIVITY_DAYS = 30

    def initialize(params = {})
      @resolver = Clients::DateRangeResolver.new(params)
      @params = params
    end

    def call
      Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
        {
          kpis: kpis,
          accounts: accounts_table,
          at_risk_accounts: at_risk_list,
          upcoming_unpaid_corporate: upcoming_unpaid_invoices
        }
      end.merge(date_range: { start_date: @resolver.start_date, end_date: @resolver.end_date, preset: @resolver.preset })
    end

    private

    def cache_key
      ["clients/corporate_insights", @resolver.start_date, @resolver.end_date, @params[:industry], @params[:active], @params[:has_overdue], @params[:min_revenue]].join("/")
    end

    def range
      @resolver.range
    end

    def corp_attendees_scope
      @corp_scope ||= Attendee.attendees.corp
        .joins(:training_class, :customer)
        .where("training_classes.date >= ? AND training_classes.date <= ?", range.begin, range.end)
        .includes(:customer, :training_class)
    end

    def corp_attendees_all_time
      @corp_all ||= Attendee.attendees.corp.joins(:training_class, :customer).includes(:customer, :training_class).to_a
    end

    def grouped_by_company
      @grouped ||= begin
        list = corp_attendees_all_time
        list.group_by { |a| a.customer&.company_name.presence || a.company.presence || "—" }
      end
    end

    def kpis
      list = corp_attendees_scope.to_a
      collected = list.select { |a| a.payment_status == "Paid" }.sum(&:total_final_price).round(2)
      booked = list.sum(&:total_final_price).round(2)
      pending = list.select { |a| a.payment_status == "Pending" }.sum(&:total_final_price).round(2)
      overdue_list = list.select { |a| a.payment_status == "Pending" && a.due_date.present? && a.due_date < Date.current }
      overdue_amt = overdue_list.sum(&:total_final_price).round(2)
      active_accounts = grouped_by_company.count
      # Avg payment days: from paid attendees, (payment_date - due_date or class date). Use payment_date when present.
      paid_with_date = list.select { |a| a.payment_status == "Paid" && (a.payment_date.present? || a.respond_to?(:payment_date_from_slips)) }
      avg_days = if paid_with_date.any?
        days = paid_with_date.map do |a|
          pd = a.payment_date.presence || (a.respond_to?(:payment_date_from_slips) ? a.payment_date_from_slips&.to_date : nil)
          ref = pd && a.due_date ? (pd - a.due_date).to_i : (a.training_class.date ? (Date.current - a.training_class.date).to_i : 0)
          ref
        end
        (days.sum.to_f / days.size).round(0)
      else
        nil
      end

      {
        corporate_revenue: collected,
        booked_revenue: booked,
        outstanding: pending,
        overdue: overdue_amt,
        active_corporate_accounts: active_accounts,
        avg_payment_days: avg_days
      }
    end

    def accounts_table
      apply_table_filters(
        grouped_by_company.map do |company_name, attendees|
          rev = attendees.select { |a| a.payment_status == "Paid" }.sum(&:total_final_price).round(2)
          out = attendees.select { |a| a.payment_status == "Pending" }.sum(&:total_final_price).round(2)
          over = attendees.select { |a| a.payment_status == "Pending" && a.due_date.present? && a.due_date < Date.current }.sum(&:total_final_price).round(2)
          classes = attendees.map(&:training_class_id).uniq.size
          last_act = attendees.map(&:updated_at).max
          last_act_date = last_act&.to_date
          health = health_badge(over, last_act_date)
          rep_customer_id = attendees.map(&:customer_id).compact.min
          rep_customer_id ||= attendees.first.customer_id

          {
            account_id: rep_customer_id,
            company_name: company_name,
            revenue: rev,
            outstanding: out,
            overdue: over,
            classes_attended: classes,
            last_activity: last_act_date,
            health: health
          }
        end
      ).sort_by { |h| -h[:revenue] }
    end

    def apply_table_filters(rows)
      rows = rows.select { |r| r[:revenue].to_f >= @params[:min_revenue].to_f } if @params[:min_revenue].present?
      rows = rows.select { |r| r[:overdue].to_f > 0 } if @params[:has_overdue] == "1"
      rows = rows.select { |r| r[:last_activity].present? && r[:last_activity] >= (Date.current - 90.days) } if @params[:active] == "1"
      rows = rows.reject { |r| r[:last_activity].present? && r[:last_activity] >= (Date.current - 90.days) } if @params[:active] == "0"
      rows
    end

    def health_badge(overdue_amt, last_activity_date)
      return "At Risk" if overdue_amt.to_f > 0 && (last_activity_date.blank? || (Date.current - last_activity_date).to_i > AT_RISK_NO_ACTIVITY_DAYS)
      return "At Risk" if last_activity_date.blank? || (Date.current - last_activity_date).to_i > AT_RISK_NO_ACTIVITY_DAYS
      return "Watch" if overdue_amt.to_f > 0 || (last_activity_date && (Date.current - last_activity_date).to_i > WATCH_NO_ACTIVITY_DAYS)
      "Good"
    end

    def at_risk_list
      accounts_table
        .select { |r| r[:health] == "At Risk" }
        .sort_by { |r| [-(r[:overdue].to_f), r[:last_activity] || Date.new(1900)] }
        .first(10)
    end

    def upcoming_unpaid_invoices
      Attendee.attendees.corp
        .joins(:training_class)
        .where(payment_status: "Pending")
        .where("training_classes.date >= ? AND training_classes.date <= ?", Date.current, 30.days.from_now.to_date)
        .includes(:customer, :training_class)
        .limit(15)
        .map { |a| { training_class_title: a.training_class.title, date: a.training_class.date, company: a.customer&.company_name.presence || a.company, amount: a.total_final_price, attendee_id: a.id, training_class_id: a.training_class_id } }
    end
  end
end
