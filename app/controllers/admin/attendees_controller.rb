module Admin
  class AttendeesController < ApplicationController
    before_action :set_training_class
    before_action :set_attendee, only: [:show, :edit, :update, :destroy, :move_to_potential, :move_to_attendee]
    skip_before_action :set_attendee, only: [:index, :new, :create, :export]
    layout "admin"
    
    def index
      @attendees = @training_class.attendees.order(:name)
    end
    
    def show
    end
    
    def new
      @attendee = @training_class.attendees.build
      @promotions = Promotion.active.order(:name)
    end
    
    def create
      @attendee = @training_class.attendees.build(attendee_params)
      
      if @attendee.save
        redirect_to admin_training_class_attendees_path(@training_class), notice: "Attendee added successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end
    
    def edit
      @promotions = Promotion.active.order(:name)
    end
    
    def update
      if @attendee.update(attendee_params)
        if params[:quick_edit]
          redirect_to admin_training_class_path(@training_class, tab: "attendees"), notice: "#{@attendee.name} updated successfully."
        else
          redirect_to admin_training_class_attendees_path(@training_class), notice: "Attendee updated successfully."
        end
      else
        if params[:quick_edit]
          redirect_to admin_training_class_path(@training_class, tab: "attendees"), alert: "Error: #{@attendee.errors.full_messages.join(', ')}"
        else
          render :edit, status: :unprocessable_entity
        end
      end
    end
    
    def destroy
      @attendee.destroy
      redirect_to admin_training_class_attendees_path(@training_class), notice: "Attendee removed successfully."
    end
    
    def move_to_potential
      @attendee.update(status: "potential")
      redirect_to admin_training_class_path(@training_class, tab: "potential"), notice: "#{@attendee.name} has been moved to Potential Customers. All information has been preserved."
    end
    
    def move_to_attendee
      @attendee.update(status: "attendee")
      redirect_to admin_training_class_path(@training_class, tab: "attendees"), notice: "#{@attendee.name} has been moved to Class Attendees. All information has been preserved."
    end
    
    def send_email
      email_type = params[:email_type] || "class_info"
      
      case email_type
      when "class_info"
        AttendeeMailer.send_class_info(@attendee).deliver_now
        message = "Class information email sent to #{@attendee.email}"
      when "reminder"
        AttendeeMailer.send_reminder(@attendee).deliver_now
        message = "Reminder email sent to #{@attendee.email}"
      when "custom"
        subject = params[:subject]
        body = params[:message]
        AttendeeMailer.send_custom(@attendee, subject, body).deliver_now
        message = "Custom email sent to #{@attendee.email}"
      else
        message = "Invalid email type"
      end
      
      redirect_to admin_training_class_path(@training_class, tab: "attendees"), notice: message
    rescue => e
      redirect_to admin_training_class_path(@training_class, tab: "attendees"), alert: "Error sending email: #{e.message}"
    end
    
    def export
      @attendees = @training_class.attendees.order(:name)
      
      respond_to do |format|
        format.csv do
          headers['Content-Disposition'] = "attachment; filename=\"#{@training_class.title.parameterize}-attendees-#{Date.today}.csv\""
          headers['Content-Type'] ||= 'text/csv'
        end
      end
    end
    
    private
    
    def set_training_class
      @training_class = TrainingClass.find(params[:training_class_id])
    end
    
    def set_attendee
      @attendee = @training_class.attendees.find(params[:id])
    end
    
    def attendee_params
      params.require(:attendee).permit(:name, :email, :phone, :company, :notes, 
                                        :participant_type, :source_channel, :payment_status, 
                                        :document_status, :attendance_status, :total_classes, :price,
                                        :invoice_no, :due_date, :payment_slip, :status, promotion_ids: [])
    end
  end
end
