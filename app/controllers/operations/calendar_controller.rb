# frozen_string_literal: true

module Operations
  class CalendarController < Operations::BaseController
    def index
      @view = params[:view].presence_in(%w[month week]) || "month"
      @anchor = parse_anchor(params[:start_date])
      @filters = filter_params

      range = date_range_for(@view, @anchor)
      @events = scope_in_range(range).to_a
      @events = @events.select { |e| (e.fill_rate_percent || 0) >= 80 } if @filters[:nearly_full] == "1"
      @events_by_date = build_events_by_date(@events, range)
      @calendar_start = range.begin
      @calendar_end = range.end
      @month_start = @calendar_start.beginning_of_month
      @month_end = @calendar_start.end_of_month
      @week_start = @calendar_start.beginning_of_week(:monday)
      @week_end = @calendar_start.end_of_week(:monday)
      @instructor_options = TrainingClass.distinct.pluck(:instructor).compact.sort
      @location_options = TrainingClass.distinct.pluck(:location).compact.sort
      # KPIs for displayed month
      month_range = @month_start..@month_end
      month_scope = TrainingClass.where("date <= ?", month_range.end).where("(end_date IS NULL AND date >= ?) OR (end_date IS NOT NULL AND end_date >= ?)", month_range.begin, month_range.begin).includes(:attendees)
      month_events = month_scope.to_a.uniq
      @kpi_total_classes = month_events.size
      @kpi_seats_sold = month_events.sum { |e| e.total_registered_seats }
      @kpi_revenue_forecast = month_events.sum { |e| e.net_revenue.to_f }
    end

    def event
      @event = TrainingClass.includes(:attendees).find_by(id: params[:id])
      unless @event
        render plain: "Class not found", status: :not_found
        return
      end
      # When opened in calendar, respond with turbo frame only; when opened directly, use full layout
      request.headers["Turbo-Frame"].present? ? (render layout: false) : (render :event_standalone)
    end

    private

    def parse_anchor(start_date_param)
      return Date.current if start_date_param.blank?
      Date.parse(start_date_param.to_s)
    rescue ArgumentError
      Date.current
    end

    def date_range_for(view, anchor)
      if view == "week"
        start_d = anchor.beginning_of_week(:monday)
        end_d = anchor.end_of_week(:monday)
      else
        start_d = anchor.beginning_of_month
        end_d = anchor.end_of_month
      end
      start_d..end_d
    end

    def scope_in_range(range)
      scope = TrainingClass.where("date <= ?", range.end)
                           .where("(end_date IS NULL AND date >= ?) OR (end_date IS NOT NULL AND end_date >= ?)", range.begin, range.begin)
                           .includes(:attendees)
                           .order(:date, :start_time)

      scope = scope.where(instructor: @filters[:instructor]) if @filters[:instructor].present?
      scope = scope.where(location: @filters[:location]) if @filters[:location].present?

      case @filters[:status]
      when "upcoming"
        scope = scope.where("date >= ? OR (end_date IS NOT NULL AND end_date >= ?)", Date.current, Date.current)
      when "past"
        scope = scope.where("date < ?", Date.current)
      when "cancelled"
        scope = scope.none
      end

      scope
    end

    def build_events_by_date(events, range)
      by_date = Hash.new { |h, k| h[k] = [] }
      events.each do |e|
        start_d = e.date
        end_d = e.end_date.presence || e.date
        (start_d..end_d).each do |d|
          by_date[d] << e if d >= range.begin && d <= range.end
        end
      end
      by_date
    end

    def filter_params
      {
        view: params[:view].presence_in(%w[month week]) || "month",
        start_date: params[:start_date].presence || Date.current.to_s,
        instructor: params[:instructor].presence,
        location: params[:location].presence,
        status: params[:status].presence_in(%w[all upcoming past cancelled]) || "all",
        type: params[:type].presence_in(%w[all public corporate]) || "all",
        nearly_full: params[:nearly_full].presence
      }
    end
  end
end
