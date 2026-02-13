# frozen_string_literal: true

module Admin
  class DashboardController < ApplicationController
    layout "admin"

    def index
      response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
      response.headers["Pragma"] = "no-cache"
      response.headers["Expires"] = "0"

      apply_filters
      filter_courses_for_select
      filter_instructors_for_select
      filter_channels_for_select
      load_kpis
      load_action_required_queue
      load_upcoming_classes
      load_leads_by_channel
      load_repeat_and_top_customers
    end

    private

    def apply_filters
      @filters = {
        period_start: params[:period_start].presence,
        period_end: params[:period_end].presence,
        preset: params[:preset].presence,
        course_id: params[:course_id].presence,
        instructor: params[:instructor].presence,
        channel: params[:channel].presence,
        status: params[:status].presence # payment_status: Paid | Pending
      }
      set_period_from_preset if @filters[:preset].present?
      @period_start = @filters[:period_start].present? ? Date.parse(@filters[:period_start]) : Date.today.beginning_of_month
      @period_end = @filters[:period_end].present? ? Date.parse(@filters[:period_end]) : Date.today.end_of_month
    end

    def set_period_from_preset
      case @filters[:preset]
      when "this_week"
        @period_start = Date.today.beginning_of_week
        @period_end = Date.today.end_of_week
      when "this_month"
        @period_start = Date.today.beginning_of_month
        @period_end = Date.today.end_of_month
      when "last_month"
        @period_start = Date.today.last_month.beginning_of_month
        @period_end = Date.today.last_month.end_of_month
      when "next_30"
        @period_start = Date.today
        @period_end = 30.days.from_now.to_date
      end
    end

    def base_classes_scope
      scope = TrainingClass.upcoming
      scope = scope.where("date >= ? AND date <= ?", @period_start, @period_end) if @period_start && @period_end
      scope = scope.where(id: @filters[:course_id]) if @filters[:course_id].present?
      scope = scope.where(instructor: @filters[:instructor]) if @filters[:instructor].present?
      scope
    end

    def base_attendees_scope
      scope = Attendee.attendees.joins(:training_class).where("training_classes.date >= ? AND training_classes.date <= ?", @period_start, @period_end)
      scope = scope.where(training_class_id: @filters[:course_id]) if @filters[:course_id].present?
      scope = scope.where(source_channel: @filters[:channel]) if @filters[:channel].present?
      scope = scope.where(payment_status: @filters[:status]) if @filters[:status].present?
      scope
    end

    def load_kpis
      classes_scope = base_classes_scope
      @total_upcoming_classes = classes_scope.count
      @total_attendees_in_period = base_attendees_scope.count
      @new_leads_in_period = Attendee.where("created_at >= ?", @period_start).where("created_at <= ?", @period_end.end_of_day)
                                     .then { |s| s = s.where(training_class_id: @filters[:course_id]) if @filters[:course_id].present?; s }
                                     .then { |s| s = s.where(source_channel: @filters[:channel]) if @filters[:channel].present?; s }
                                     .count
      @repeat_learners = Attendee.attendees.where("total_classes > ?", 0).distinct.count(:email)
      @pending_qt = Attendee.attendees.where(document_status: [nil, ""], payment_status: "Pending").count
      @inv_not_confirmed = Attendee.attendees.where(document_status: "INV", payment_status: "Pending").count
      @receipt_not_issued = Attendee.attendees.where(payment_status: "Paid").where.not(document_status: "Receipt").count
      # Single query: count classes where registered seats >= 90% of max_attendees (no custom select so .count works)
      near_full_sql = classes_scope.joins(:attendees)
        .where(attendees: { status: [nil, "attendee"] })
        .group("training_classes.id")
        .having("training_classes.max_attendees > 0 AND (SUM(attendees.seats) * 1.0 / training_classes.max_attendees) >= 0.9")
      @classes_near_full_count = near_full_sql.count.size
      @classes_near_full = [] # not used for list, only count; keep for compatibility
      # Optional deltas for trend (nil = hide)
      @kpi_deltas = { upcoming: nil, attendees: nil, leads: nil, repeat: nil, pending_qt: nil, unpaid_inv: nil, receipts: nil, near_full: nil }
    end

    def load_action_required_queue
      @action_required_queue = []
      @action_required_queue << { severity: :critical, label: "Unpaid invoices", count: @inv_not_confirmed, url: admin_finance_index_path, cta: "View" } if @inv_not_confirmed > 0
      @action_required_queue << { severity: :warning, label: "Pending QT", count: @pending_qt, url: admin_finance_index_path, cta: "View" } if @pending_qt > 0
      @action_required_queue << { severity: :info, label: "Missing receipts", count: @receipt_not_issued, url: admin_finance_index_path, cta: "View" } if @receipt_not_issued > 0
      @action_required_queue << { severity: :warning, label: "Class almost full", count: @classes_near_full_count, url: admin_training_classes_path, cta: "View" } if @classes_near_full_count > 0
    end

    def load_upcoming_classes
      @upcoming_classes = base_classes_scope.limit(10).includes(:attendees)
    end

    def load_leads_by_channel
      scope = Attendee.where("created_at >= ?", @period_start).where("created_at <= ?", @period_end.end_of_day)
      scope = scope.where(training_class_id: @filters[:course_id]) if @filters[:course_id].present?
      @leads_by_channel = scope.group(:source_channel).count.transform_keys { |k| k.presence || "Unknown" }
      @leads_total = @leads_by_channel.values.sum
    end

    def load_repeat_and_top_customers
      @repeat_customers = Customer.joins(:attendees)
                                  .where(attendees: { status: [nil, "attendee"] })
                                  .group("customers.id")
                                  .having("COUNT(attendees.id) > 1")
                                  .select("customers.*, COUNT(attendees.id) as attendee_count")
                                  .order(Arel.sql("COUNT(attendees.id) DESC"))
                                  .limit(10)
      @top_customers_by_revenue = Customer.joins(:attendees)
                                          .where(attendees: { status: [nil, "attendee"], payment_status: "Paid" })
                                          .group("customers.id")
                                          .select("customers.*, SUM(COALESCE(attendees.total_amount, attendees.price * attendees.seats)) as total_spent")
                                          .order(Arel.sql("SUM(COALESCE(attendees.total_amount, attendees.price * attendees.seats)) DESC"))
                                          .limit(10)
    end

    def filter_courses_for_select
      @filter_courses = TrainingClass.upcoming.order(:date).limit(50).pluck(:id, :title, :date)
    end

    def filter_instructors_for_select
      @filter_instructors = TrainingClass.upcoming.where.not(instructor: [nil, ""]).distinct.pluck(:instructor).sort
    end

    def filter_channels_for_select
      @filter_channels = Attendee.where.not(source_channel: [nil, ""]).distinct.pluck(:source_channel).sort
    end
  end
end
