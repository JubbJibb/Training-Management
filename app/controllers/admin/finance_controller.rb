# frozen_string_literal: true

module Admin
  class FinanceController < ApplicationController
    layout "admin"

    def index
      @attendees = filtered_attendees
      @training_classes = TrainingClass.order(date: :desc).limit(100)

      # SECTION 1: Revenue Overview
      @gross_sales = @attendees.sum(&:gross_sales_amount)
      @total_discounts = @attendees.sum { |a| a.total_discount_amount * (a.seats || 1) }
      @net_before_vat = @attendees.sum(&:total_price_before_vat)
      @vat_amount = @attendees.sum(&:total_vat_amount)
      @total_incl_vat = @attendees.sum(&:total_final_price)

      # SECTION 2: Cash Flow
      @cash_received = @attendees.where(payment_status: "Paid").sum(&:total_final_price)
      @outstanding = @attendees.where(payment_status: "Pending").sum(&:total_final_price)
      @overdue_amount = @attendees.where(payment_status: "Pending").where("due_date < ?", Date.current).sum(&:total_final_price)
      @collection_rate_pct = @total_incl_vat.positive? ? ((@cash_received / @total_incl_vat) * 100).round(1) : 0

      # SECTION 3: Revenue Breakdown
      @revenue_by_course = revenue_by_course
      @revenue_by_type = { "Corporate" => @attendees.where(participant_type: "Corp").sum(&:total_final_price), "Individual" => @attendees.where(participant_type: "Indi").sum(&:total_final_price) }
      @revenue_by_channel = @attendees.group_by { |a| a.source_channel.presence || "—" }.transform_values { |list| list.sum(&:total_final_price) }.sort_by { |_k, v| -v }.to_h
      @revenue_by_status = {
        paid: @attendees.where(payment_status: "Paid").sum(&:total_final_price),
        pending: @attendees.where(payment_status: "Pending").sum(&:total_final_price),
        receipt_issued: @attendees.where(document_status: "Receipt").sum(&:total_final_price),
        receipt_not_issued: @attendees.where(payment_status: "Paid").where.not(document_status: "Receipt").sum(&:total_final_price)
      }

      # SECTION 4: Revenue Structure (Pricing Funnel) & KPIs
      @total_seats = @attendees.sum(:seats) || 0
      @discount_rate_pct = @gross_sales.positive? ? ((@total_discounts / @gross_sales) * 100).round(1) : 0
      @avg_discount_per_seat = @total_seats.positive? ? (@total_discounts / @total_seats).round(2) : 0
      # Avg revenue per seat = Net (before VAT) per seat (finance-logical)
      @avg_revenue_per_seat = @total_seats.positive? ? (@net_before_vat / @total_seats).round(2) : 0
      corp_revenue = @revenue_by_type["Corporate"]
      indi_revenue = @revenue_by_type["Individual"]
      @corp_vs_indi_pct = @total_incl_vat.positive? ? ((corp_revenue / @total_incl_vat) * 100).round(1) : 0
      @payment_cycle_avg_days = payment_cycle_avg_days

      # SECTION 5: Action Required (counts + links)
      @pending_qt_count = @attendees.where("document_status IS NULL OR document_status = ''").where(payment_status: "Pending").count
      @inv_unpaid_count = @attendees.where(document_status: "INV", payment_status: "Pending").count
      @overdue_count = @attendees.where(payment_status: "Pending").where("due_date < ?", Date.current).count
      @paid_no_receipt_count = @attendees.where(payment_status: "Paid").where.not(document_status: "Receipt").count
      @due_this_week = @attendees.where(payment_status: "Pending").where(due_date: Date.current.beginning_of_week..Date.current.end_of_week).count

      # SECTION 3 (Cost & Profit): total cost of classes in scope, profit = net before VAT - cost
      class_ids_in_scope = @attendees.pluck(:training_class_id).uniq
      @total_cost = TrainingClass.where(id: class_ids_in_scope).sum { |tc| tc.total_cost }
      @profit = @net_before_vat - @total_cost

      # SECTION 6: Corporate Billing Overview (Gross, Discount, Net, Paid, Outstanding, Status)
      @corporate_billing = calculate_corporate_billing

      # Action list (when user clicks an action card, show matching attendees)
      @action_list = params[:action_list]
      @action_list_attendees = action_list_attendees if @action_list.present?

      # Export
      respond_to do |format|
        format.html
        format.csv do
          send_data finance_export_csv, filename: "finance-overview-#{Date.current}.csv", type: "text/csv"
        end
      end
    end

    private

    def filtered_attendees
      scope = Attendee.attendees.joins(:training_class).includes(:training_class, :customer)
      scope = scope.where(training_class_id: params[:training_class_id]) if params[:training_class_id].present?
      scope = scope.where(participant_type: params[:type]) if params[:type].present? && %w[Corp Indi].include?(params[:type])
      if params[:date_from].present?
        from = Date.parse(params[:date_from]) rescue nil
        scope = scope.where("training_classes.date >= ?", from) if from
      end
      if params[:date_to].present?
        to = Date.parse(params[:date_to]) rescue nil
        scope = scope.where("training_classes.date <= ?", to) if to
      end
      scope
    end

    def revenue_by_course
      @attendees.group_by(&:training_class).transform_values { |list| list.sum(&:total_final_price) }.sort_by { |_k, v| -v }
    end

    def payment_cycle_avg_days
      paid = @attendees.where(payment_status: "Paid").where.not(due_date: nil)
      return nil if paid.empty?
      # Approximate: use (due_date - created_at) as proxy for "days to pay" if we had paid_at
      days = paid.select { |a| a.created_at && a.due_date }.map { |a| (a.due_date - a.created_at.to_date).to_i }
      days.any? ? (days.sum.to_f / days.size).round(0) : nil
    end

    def calculate_corporate_billing
      corp = @attendees.where(participant_type: "Corp")
      by_company = corp.group_by { |a| a.customer&.company_name.presence || a.company.presence || "—" }
      by_company.map do |company, list|
        gross = list.sum(&:gross_sales_amount)
        discount = list.sum { |a| a.total_discount_amount * (a.seats || 1) }
        net = list.sum(&:total_price_before_vat)
        total = list.sum(&:total_final_price)
        paid = list.select { |a| a.payment_status == "Paid" }.sum(&:total_final_price)
        outstanding = total - paid
        {
          company: company,
          gross: gross,
          discount: discount,
          net: net,
          paid: paid,
          outstanding: outstanding,
          status: outstanding > 0 ? "Pending" : "Paid"
        }
      end.sort_by { |h| -h[:outstanding] }
    end

    def action_list_attendees
      scope = @attendees
      case @action_list
      when "pending_qt"
        scope.where("document_status IS NULL OR document_status = ''").where(payment_status: "Pending")
      when "inv_unpaid"
        scope.where(document_status: "INV", payment_status: "Pending")
      when "overdue"
        scope.where(payment_status: "Pending").where("due_date < ?", Date.current)
      when "paid_no_receipt"
        scope.where(payment_status: "Paid").where.not(document_status: "Receipt")
      when "due_this_week"
        scope.where(payment_status: "Pending").where(due_date: Date.current.beginning_of_week..Date.current.end_of_week)
      else
        scope.none
      end
    end

    def finance_export_csv
      require "csv"
      CSV.generate(headers: true) do |csv|
        csv << ["Metric", "Value"]
        csv << ["Gross Sales", @gross_sales]
        csv << ["Total Discounts", @total_discounts]
        csv << ["Net (Before VAT)", @net_before_vat]
        csv << ["VAT 7%", @vat_amount]
        csv << ["Total (Incl. VAT)", @total_incl_vat]
        csv << ["Cash Received", @cash_received]
        csv << ["Outstanding", @outstanding]
        csv << ["Overdue", @overdue_amount]
        csv << ["Collection Rate %", @collection_rate_pct]
      end
    end
  end
end
