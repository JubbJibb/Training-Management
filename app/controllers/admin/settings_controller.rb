module Admin
  class SettingsController < ApplicationController
    before_action :set_promotion, only: [:edit, :update, :destroy]
    layout "admin"
    
    def index
      @promotions = Promotion.order(:name)
    end
    
    def new
      @promotion = Promotion.new
    end
    
    def create
      @promotion = Promotion.new(promotion_params)
      
      if @promotion.save
        redirect_to admin_settings_path, notice: "Promotion created successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end
    
    def edit
    end
    
    def update
      if @promotion.update(promotion_params)
        redirect_to admin_settings_path, notice: "Promotion updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end
    
    def destroy
      @promotion.destroy
      redirect_to admin_settings_path, notice: "Promotion deleted successfully."
    end
    
    private
    
    def set_promotion
      @promotion = Promotion.find(params[:id])
    end
    
    def promotion_params
      params.require(:promotion).permit(:name, :discount_type, :discount_value, :description, :active, :base_price)
    end
  end
end
