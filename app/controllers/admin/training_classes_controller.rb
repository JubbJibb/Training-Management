module Admin
  class TrainingClassesController < ApplicationController
    layout "admin"
    
    def index
      @tab = params[:tab].presence || "upcoming"
      @filter_instructors = TrainingClass.distinct.pluck(:instructor).compact.sort
      load_training_classes_kpis
      load_training_classes_for_tab
    end
    
    def show
      @training_class = TrainingClass.find(params[:id])
      @attendees = @training_class.attendees.attendees.includes(:customer).order(:name)
      @potential_customers = @training_class.attendees.potential_customers.order(:name)
      @document_summary = DocumentSummaryService.new(@training_class.id).summary
      # Finance tab: load dashboard inline so the frame doesn't depend on a second request (avoids loading issues when frame is inside hidden tab)
      @finance_dashboard = ::Finance::ClassFinanceDashboardQuery.new(
        @training_class,
        type: params[:type].presence, status: params[:status].presence,
        expense_category: params[:expense_category].presence,
        expense_date_from: params[:expense_date_from].presence,
        expense_date_to: params[:expense_date_to].presence
      ).call
    end

    def finance
      @training_class = TrainingClass.find(params[:id])
      # When opened directly (not Turbo Frame), show full class page with Finance tab so design matches other pages
      unless request.headers["Turbo-Frame"].to_s.present?
        redirect_to admin_training_class_path(
          @training_class,
          tab: "finance",
          sub: params[:sub],
          type: params[:type],
          status: params[:status],
          expense_category: params[:expense_category],
          expense_date_from: params[:expense_date_from],
          expense_date_to: params[:expense_date_to]
        ) and return
      end
      @finance_dashboard = ::Finance::ClassFinanceDashboardQuery.new(
        @training_class,
        type: params[:type].presence, status: params[:status].presence,
        expense_category: params[:expense_category].presence,
        expense_date_from: params[:expense_date_from].presence,
        expense_date_to: params[:expense_date_to].presence
      ).call
      render layout: false
    end
    
    def new
      @training_class = TrainingClass.new
      if params[:course_id].present?
        course = Course.find_by(id: params[:course_id])
        if course
          @course = course
          @training_class.title = course.title
          @training_class.description = course.description
          @training_class.max_attendees = course.capacity if course.capacity.present?
        end
      end
    end
    
    def create
      @training_class = TrainingClass.new(training_class_params)
      
      if @training_class.save
        redirect_to admin_training_class_path(@training_class), notice: "Training class created successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end
    
    def edit
      @training_class = TrainingClass.find(params[:id])
    end
    
    def update
      @training_class = TrainingClass.find(params[:id])
      
      if @training_class.update(training_class_params)
        redirect_to admin_training_class_path(@training_class), notice: "Training class updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end
    
    def destroy
      @training_class = TrainingClass.find(params[:id])
      
      if @training_class.destroy
        redirect_to admin_training_classes_path, notice: "Training class deleted successfully."
      else
        redirect_to admin_training_classes_path, alert: "Failed to delete training class: #{@training_class.errors.full_messages.join(', ')}"
      end
    rescue => e
      redirect_to admin_training_classes_path, alert: "Error deleting training class: #{e.message}"
    end
    
    def send_email_to_all
      @training_class = TrainingClass.find(params[:id])
      subject = params[:subject]
      message = params[:message]
      
      if subject.blank? || message.blank?
        redirect_to admin_training_class_path(@training_class), alert: "Subject and message are required."
        return
      end
      
      attendee_count = @training_class.attendees.attendees.count
      
      if attendee_count == 0
        redirect_to admin_training_class_path(@training_class), alert: "No attendees to send email to."
        return
      end
      
      @training_class.attendees.attendees.each do |attendee|
        AttendeeMailer.send_custom(attendee, subject, message).deliver_now
      end
      
      redirect_to admin_training_class_path(@training_class), notice: "Email sent to #{attendee_count} attendee(s)."
    rescue => e
      redirect_to admin_training_class_path(@training_class), alert: "Error sending emails: #{e.message}"
    end
    
    private

    def load_training_classes_kpis
      upcoming = TrainingClass.upcoming
      @kpi_upcoming_count = upcoming.count
      # Average fill rate (upcoming classes with max_attendees only)
      with_max = upcoming.select { |tc| tc.max_attendees.present? && tc.max_attendees.positive? }
      @kpi_avg_fill_rate = if with_max.any?
        (with_max.sum { |tc| tc.fill_rate_percent || 0 }.to_f / with_max.size).round(0)
      else
        0
      end
      next_30_end = 30.days.from_now.to_date
      next_30_classes = upcoming.where("date <= ?", next_30_end)
      @kpi_seats_next_30 = next_30_classes.sum { |tc| tc.total_registered_seats }
      @kpi_revenue_forecast = next_30_classes.sum(&:net_revenue)
      past_30_start = 30.days.ago.to_date
      past_30_classes = TrainingClass.past.where("(end_date IS NOT NULL AND end_date >= ?) OR (end_date IS NULL AND date >= ?)", past_30_start, past_30_start)
      @kpi_past_30_revenue = past_30_classes.sum(&:net_revenue)
    end

    def load_training_classes_for_tab
      case @tab
      when "past"
        @training_classes = TrainingClass.past
        @empty_state_message = "No past classes."
        @empty_state_icon = "clock-history"
      when "cancelled"
        @training_classes = TrainingClass.cancelled
        @empty_state_message = "No cancelled classes."
        @empty_state_icon = "x-circle"
      else
        @training_classes = TrainingClass.upcoming
        @empty_state_message = "No upcoming classes. Create one to get started."
        @empty_state_icon = "calendar-x"
      end
      apply_tc_filters
    end

    def apply_tc_filters
      @training_classes = @training_classes.where(instructor: params[:instructor]) if params[:instructor].present?
      if params[:date_from].present?
        @training_classes = @training_classes.where("date >= ?", Date.parse(params[:date_from]))
      end
      if params[:date_to].present?
        @training_classes = @training_classes.where("(end_date IS NOT NULL AND end_date <= ?) OR (end_date IS NULL AND date <= ?)", Date.parse(params[:date_to]), Date.parse(params[:date_to]))
      end
    end

    def training_class_params
      params.require(:training_class).permit(:title, :description, :date, :end_date, :start_time, :end_time, :location, :max_attendees, :instructor, :cost, :price)
    end
  end
end
