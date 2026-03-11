# frozen_string_literal: true

module Operations
  class TrainingCalendarController < Operations::BaseController
    before_action :set_filters, only: [:index, :drawer, :day_popover, :day_modal, :create_class, :update_class]
    before_action :set_date_range, only: [:index, :create_class, :update_class]

    def index
      @events = scope_in_range(@range).to_a
      @events = @events.select { |e| (e.fill_rate_percent || 0) >= 80 } if @filters[:nearly_full] == "1"
      @events_by_date = build_events_by_date(@events, @range)
      @instructor_options = TrainingClass.distinct.pluck(:instructor).compact.sort
      @location_options = TrainingClass.distinct.pluck(:location).compact.sort
      compute_kpis
      # For month label and week range in header
      @month_start = @range.begin.beginning_of_month
      @month_end = @range.begin.end_of_month
      @week_start = @range.begin.beginning_of_week(:monday)
      @week_end = @range.end.end_of_week(:monday)
    end

    def drawer
      if params[:id].present?
        @training_class = TrainingClass.includes(:attendees).find_by(id: params[:id])
        unless @training_class
          render plain: "Class not found", status: :not_found
          return
        end
        render partial: "operations/training_calendar/drawer/form", locals: { training_class: @training_class }, layout: false
      else
        render partial: "operations/training_calendar/drawer/empty", layout: false
      end
    end

    def day_popover
      date = params[:date].present? ? Date.parse(params[:date].to_s) : Date.current
      range = date..date
      events = scope_in_range(range).to_a
      @events = events.sort_by { |e| [e.date, e.start_time || Time.current] }
      @date = date
      render partial: "operations/training_calendar/day_popover", layout: false
    end

    def event_modal
      @training_class = TrainingClass.includes(:attendees).find_by(id: params[:id])
      unless @training_class
        render turbo_stream: turbo_stream.replace("tc_event_modal", ""), status: :ok
        return
      end
      render partial: "operations/training_calendar/modals/event_details", locals: { training_class: @training_class }, layout: false
    end

    def day_modal
      date = params[:date].present? ? Date.parse(params[:date].to_s) : Date.current
      range = date..date
      events = scope_in_range(range).to_a
      @events = events.sort_by { |e| [e.date, e.start_time || Time.current] }
      @date = date
      render partial: "operations/training_calendar/modals/day_events", layout: false
    end

    def modal_close
      which = params[:which].presence_in(%w[event day]) || "event"
      frame_id = which == "day" ? "tc_day_modal" : "tc_event_modal"
      render partial: "operations/training_calendar/modals/close", locals: { frame_id: frame_id }, layout: false
    end

    def quick_add_form
      date = params[:date].present? ? Date.parse(params[:date].to_s) : Date.current
      time = params[:time].presence
      tc = TrainingClass.new(date: date)
      tc.start_time = Time.zone.parse("#{date} #{time}") if time.present?
      render partial: "operations/training_calendar/popovers/quick_add", locals: { training_class: tc, date: date, time: time }, layout: false
    end

    def create_class
      @training_class = TrainingClass.new(training_class_params)
      if @training_class.save
        set_date_range
        @events = scope_in_range(@range).to_a
        @events = @events.select { |e| (e.fill_rate_percent || 0) >= 80 } if @filters[:nearly_full] == "1"
        @events_by_date = build_events_by_date(@events, @range)
        compute_kpis
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.replace("tc_event_modal", ""),
              turbo_stream.replace("tc_kpis", partial: "operations/training_calendar/kpis", locals: kpis_locals),
              turbo_stream.replace("tc_calendar", partial: calendar_partial, locals: calendar_locals),
              turbo_stream.append("floating-ui-root", partial: "operations/training_calendar/popovers/quick_add_close", locals: {})
            ], status: :ok
          end
          format.html { redirect_to operations_training_calendar_path, notice: "Class created." }
        end
      else
        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.replace("quick_add_form", partial: "operations/training_calendar/popovers/quick_add", locals: { training_class: @training_class, date: params[:date], time: params[:time] }), status: :unprocessable_entity }
          format.html { redirect_to operations_training_calendar_path, alert: @training_class.errors.full_messages.to_sentence }
        end
      end
    end

    def update_class
      @training_class = TrainingClass.find(params[:id])
      if @training_class.update(training_class_params)
        set_date_range
        @events = scope_in_range(@range).to_a
        @events = @events.select { |e| (e.fill_rate_percent || 0) >= 80 } if @filters[:nearly_full] == "1"
        @events_by_date = build_events_by_date(@events, @range)
        compute_kpis
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.replace("tc_event_modal", ""),
              turbo_stream.replace("tc_kpis", partial: "operations/training_calendar/kpis", locals: kpis_locals),
              turbo_stream.replace("tc_calendar", partial: calendar_partial, locals: calendar_locals)
            ], status: :ok
          end
          format.html { redirect_to operations_training_calendar_path, notice: "Class updated." }
        end
      else
        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.replace("tc_event_modal", partial: "operations/training_calendar/modals/event_details", locals: { training_class: @training_class }), status: :unprocessable_entity }
          format.html { redirect_to operations_training_calendar_path, alert: @training_class.errors.full_messages.to_sentence }
        end
      end
    end

    private

    def set_filters
      @filters = filter_params
    end

    def set_date_range
      @view = params[:view].presence_in(%w[month week agenda]) || "month"
      anchor = parse_anchor(params[:start_date])
      @range = date_range_for(@view, anchor)
    end

    def parse_anchor(start_date_param)
      return Date.current if start_date_param.blank?
      Date.parse(start_date_param.to_s)
    rescue ArgumentError
      Date.current
    end

    def date_range_for(view, anchor)
      case view
      when "month"
        anchor.beginning_of_month..anchor.end_of_month
      when "agenda"
        # TODO: optional custom range; default to week
        anchor.beginning_of_week(:monday)..anchor.end_of_week(:monday)
      else
        anchor.beginning_of_week(:monday)..anchor.end_of_week(:monday)
      end
    end

    def scope_in_range(range)
      scope = TrainingClass
        .where("date <= ?", range.end)
        .where("(end_date IS NULL AND date >= ?) OR (end_date IS NOT NULL AND end_date >= ?)", range.begin, range.begin)
        .includes(:attendees)
        .order(:date, :start_time)
      scope = scope.where(instructor: @filters[:instructor]) if @filters[:instructor].present?
      scope = scope.where(location: @filters[:location]) if @filters[:location].present?
      scope = scope.where("title ILIKE ? OR instructor ILIKE ?", "%#{@filters[:q]}%", "%#{@filters[:q]}%") if @filters[:q].present?
      case @filters[:status]
      when "upcoming"
        scope = scope.where("date >= ? OR (end_date IS NOT NULL AND end_date >= ?)", Date.current, Date.current)
      when "past"
        scope = scope.where("date < ?", Date.current)
      when "cancelled"
        scope = scope.none
      end
      case @filters[:type]
      when "public"
        scope = scope.where(class_status: "public")
      when "private"
        scope = scope.where(class_status: "private")
      when "tentative"
        scope = scope.where(class_status: "tentative")
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
        view: params[:view].presence_in(%w[month week agenda]) || "month",
        start_date: params[:start_date].presence || Date.current.to_s,
        q: params[:q].presence,
        instructor: params[:instructor].presence,
        location: params[:location].presence,
        status: params[:status].presence_in(%w[all upcoming past cancelled]) || "all",
        type: params[:type].presence_in(%w[all public private tentative]) || "all",
        nearly_full: params[:nearly_full].presence
      }
    end

    def compute_kpis
      range = @range
      scope = TrainingClass
        .where("date <= ?", range.end)
        .where("(end_date IS NULL AND date >= ?) OR (end_date IS NOT NULL AND end_date >= ?)", range.begin, range.begin)
        .includes(:attendees)
      scope = scope.where(instructor: @filters[:instructor]) if @filters[:instructor].present?
      scope = scope.where(location: @filters[:location]) if @filters[:location].present?
      scope = scope.where("title ILIKE ? OR instructor ILIKE ?", "%#{@filters[:q]}%", "%#{@filters[:q]}%") if @filters[:q].present?
      events = scope.to_a.uniq
      events = events.select { |e| (e.fill_rate_percent || 0) >= 80 } if @filters[:nearly_full] == "1"

      @kpi_classes = events.size
      @kpi_seats_sold = events.sum { |e| e.total_registered_seats }
      @kpi_revenue = events.sum { |e| e.net_revenue.to_f }
      total_cap = events.sum { |e| e.max_attendees.to_i }
      @kpi_utilization = total_cap.positive? ? (events.sum { |e| e.total_registered_seats }.to_f / total_cap * 100).round(1) : nil
      @kpi_nearly_full = events.count { |e| (e.fill_rate_percent || 0) >= 80 }
    end

    def kpis_locals
      {
        kpi_classes: @kpi_classes || 0,
        kpi_seats_sold: @kpi_seats_sold || 0,
        kpi_revenue: @kpi_revenue || 0,
        kpi_utilization: @kpi_utilization,
        kpi_nearly_full: @kpi_nearly_full || 0
      }
    end

    def calendar_partial
      case @view
      when "month" then "operations/training_calendar/calendar_month"
      when "agenda" then "operations/training_calendar/calendar_agenda"
      else "operations/training_calendar/calendar_week"
      end
    end

    def calendar_locals
      {
        view: @view,
        range: @range,
        events: @events,
        events_by_date: @events_by_date,
        week_start: @range.begin.beginning_of_week(:monday),
        week_end: @range.end.end_of_week(:monday),
        month_start: @range.begin.beginning_of_month,
        month_end: @range.begin.end_of_month,
        filters: @filters
      }
    end

    def training_class_params
      params.require(:training_class).permit(:title, :description, :date, :end_date, :start_time, :end_time, :location, :max_attendees, :instructor, :cost, :price)
    end
  end
end
