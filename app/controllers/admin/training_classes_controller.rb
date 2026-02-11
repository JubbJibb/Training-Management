module Admin
  class TrainingClassesController < ApplicationController
    layout "admin"
    
    def index
      # Show upcoming classes first, then past classes
      # This matches the dashboard logic - using the same scope
      @upcoming_classes = TrainingClass.upcoming
      @past_classes = TrainingClass.past
      @training_classes = @upcoming_classes + @past_classes
    end
    
    def show
      @training_class = TrainingClass.find(params[:id])
      @attendees = @training_class.attendees.attendees.order(:name)
      @potential_customers = @training_class.attendees.potential_customers.order(:name)
    end
    
    def new
      @training_class = TrainingClass.new
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
    
    def training_class_params
      params.require(:training_class).permit(:title, :description, :date, :end_date, :start_time, :end_time, :location, :max_attendees, :instructor, :cost, :price)
    end
  end
end
