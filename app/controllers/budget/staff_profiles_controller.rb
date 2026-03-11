# frozen_string_literal: true

module Budget
  class StaffProfilesController < Budget::BaseController
    before_action :set_staff_profile, only: [:edit, :update]

    def new
      @staff_profile = Budget::StaffProfile.new(status: "active")
    end

    def create
      @staff_profile = Budget::StaffProfile.new(staff_profile_params)
      if @staff_profile.save
        redirect_to budget_staff_directory_path, notice: "Staff profile created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @staff_profile.update(staff_profile_params)
        redirect_to budget_staff_directory_path, notice: "Staff profile updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_staff_profile
      @staff_profile = Budget::StaffProfile.find(params[:id])
    end

    def staff_profile_params
      params.require(:budget_staff_profile).permit(:name, :nickname, :phone, :email, :role, :department, :internal_day_rate, :status, :effective_from, :end_date)
    end
  end
end
