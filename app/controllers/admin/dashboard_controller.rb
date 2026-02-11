module Admin
  class DashboardController < ApplicationController
    layout "admin"
    
    def index
      # Prevent caching of dashboard data
      response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
      response.headers["Pragma"] = "no-cache"
      response.headers["Expires"] = "0"
      
      # KPI
      @total_upcoming_classes = TrainingClass.upcoming.count
      @total_attendees_this_month = Attendee.attendees.joins(:training_class)
                                            .where("training_classes.date >= ?", Date.today.beginning_of_month)
                                            .count
      @new_leads_this_week = Attendee.where("created_at >= ?", 1.week.ago).count
      @repeat_learners = Attendee.attendees.where("total_classes > ?", 0).distinct.count(:email)
      
      # Action Required
      @pending_qt = Attendee.attendees.where(document_status: [nil, ""], payment_status: "Pending").count
      @inv_not_confirmed = Attendee.attendees.where(document_status: "INV", payment_status: "Pending").count
      @classes_near_full = TrainingClass.upcoming.select do |tc|
        tc.max_attendees && (tc.attendees.attendees.count.to_f / tc.max_attendees >= 0.9)
      end
      
      # Upcoming Classes (sorted by date ascending - earliest first)
      # Using the scope which already filters and orders by date
      @upcoming_classes = TrainingClass.upcoming.limit(10).includes(:attendees)
      
      # Leads by Channel
      @leads_by_channel = Attendee.where("created_at >= ?", 1.month.ago)
                                  .group(:source_channel)
                                  .count
      
      # Recent Activity (last 10 attendees with valid training classes)
      @recent_activity = Attendee.attendees.joins(:training_class)
                                 .order(created_at: :desc)
                                 .limit(10)
                                 .includes(:training_class)
    end
  end
end

