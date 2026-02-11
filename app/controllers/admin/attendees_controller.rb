module Admin
  class AttendeesController < ApplicationController
    before_action :set_training_class
    before_action :set_attendee, only: [:show, :edit, :update, :destroy]
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
        redirect_to admin_training_class_attendees_path(@training_class), notice: "Attendee updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end
    
    def destroy
      @attendee.destroy
      redirect_to admin_training_class_attendees_path(@training_class), notice: "Attendee removed successfully."
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
                                        :invoice_no, :due_date, :payment_slip, promotion_ids: [])
    end
  end
end
