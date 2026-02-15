# frozen_string_literal: true

module Clients
  # Single corporate account profile for show page: snapshot, AR, program portfolio, contacts, opportunities.
  class CorporateAccountProfile
    CACHE_TTL = 5.minutes
    NO_ACTIVITY_ALERT_DAYS = 90

    def initialize(customer_id:, params: {})
      @customer_id = customer_id
      @params = params
    end

    def call
      return { error: "not_found" } unless representative_customer
      Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
        {
          snapshot: snapshot,
          ar_aging: ar_aging,
          invoice_list: invoice_list,
          program_portfolio: program_portfolio,
          stakeholders: stakeholders,
          opportunities: opportunities
        }
      end.merge(account_name: representative_customer.company_name)
    end

    private

    def representative_customer
      @representative_customer ||= Customer.find_by(id: @customer_id)
    end

    def cache_key
      ["clients/corporate_profile", @customer_id].join("/")
    end

    def account_customer_ids
      @account_customer_ids ||= Customer.where(
        "COALESCE(billing_name, company, name) = ?",
        representative_customer.company_name
      ).pluck(:id)
    end

    def account_attendees
      @account_attendees ||= Attendee.attendees.corp
        .where(customer_id: account_customer_ids)
        .includes(:customer, :training_class)
        .to_a
    end

    def snapshot
      rev = account_attendees.select { |a| a.payment_status == "Paid" }.sum(&:total_final_price).round(2)
      ytd_start = Date.current.beginning_of_year
      ytd_rev = account_attendees.select { |a| a.payment_status == "Paid" && a.training_class.date >= ytd_start }.sum(&:total_final_price).round(2)
      out = account_attendees.select { |a| a.payment_status == "Pending" }.sum(&:total_final_price).round(2)
      over = account_attendees.select { |a| a.payment_status == "Pending" && a.due_date.present? && a.due_date < Date.current }.sum(&:total_final_price).round(2)
      classes = account_attendees.map(&:training_class_id).uniq.size
      repeat_rate = account_customer_ids.size > 1 ? 100.0 : (classes > 1 ? 100.0 : 0.0)
      last_act = account_attendees.map(&:updated_at).max&.to_date

      {
        lifetime_revenue: rev,
        ytd_revenue: ytd_rev,
        outstanding: out,
        overdue: over,
        classes_attended: classes,
        repeat_rate: repeat_rate,
        last_activity: last_act
      }
    end

    def ar_aging
      pending = account_attendees.select { |a| a.payment_status == "Pending" && a.due_date.present? }
      today = Date.current
      [
        { range: "0-30", amount: pending.select { |a| (today - a.due_date).to_i <= 30 }.sum(&:total_final_price).round(2) },
        { range: "31-60", amount: pending.select { |a| d = (today - a.due_date).to_i; d >= 31 && d <= 60 }.sum(&:total_final_price).round(2) },
        { range: "60+", amount: pending.select { |a| (today - a.due_date).to_i > 60 }.sum(&:total_final_price).round(2) }
      ]
    end

    def invoice_list
      account_attendees
        .select { |a| a.payment_status == "Pending" || a.document_status.present? }
        .sort_by { |a| [a.due_date || Date.new(9999), -a.total_final_price] }
        .first(30)
        .map { |a| { invoice_no: a.invoice_no.presence || a.quotation_no.presence || "—", due_date: a.due_date, amount: a.total_final_price, status: a.payment_status, training_class_title: a.training_class.title } }
    end

    def program_portfolio
      account_attendees
        .group_by { |a| a.training_class.title }
        .map do |title, list|
          tc = list.first.training_class
          rev = list.select { |a| a.payment_status == "Paid" }.sum(&:total_final_price).round(2)
          net = list.sum(&:total_price_before_vat).round(2)
          cost = tc.total_cost
          profit = (net - cost).round(2)
          last_date = list.map { |a| a.training_class.date }.max
          { program: title, classes: list.map(&:training_class_id).uniq.size, revenue: rev, profit: profit, last_attended: last_date }
        end
        .sort_by { |h| -h[:revenue] }
    end

    def stakeholders
      contacts = account_attendees.map(&:customer).compact.uniq
      billing = contacts.map { |c| c.billing_name.presence || c.name }.compact.uniq.first(3)
      {
        billing_contacts: billing,
        tax_id: representative_customer.tax_id,
        billing_address: representative_customer.billing_address.presence || representative_customer.address
      }
    end

    def opportunities
      list = []
      list << { type: "no_activity_90_days", message: "No activity in 90+ days" } if snapshot[:last_activity].blank? || (Date.current - snapshot[:last_activity]).to_i >= NO_ACTIVITY_ALERT_DAYS
      top_programs = program_portfolio.first(3).map { |p| p[:program] }
      list << { type: "upsell", message: "Consider upsell: #{top_programs.join(', ')}" } if top_programs.any?
      list
    end
  end
end
