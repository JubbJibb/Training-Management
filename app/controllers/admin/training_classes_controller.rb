module Admin
  class TrainingClassesController < ApplicationController
    layout "admin"
    
    def index
      @training_classes = TrainingClass.order(date: :asc)
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
      @training_class.destroy
      redirect_to admin_training_classes_path, notice: "Training class deleted successfully."
    end
    
    private
    
    def training_class_params
      params.require(:training_class).permit(:title, :description, :date, :start_time, :end_time, :location, :max_attendees, :instructor, :cost)
    end
  end
end
