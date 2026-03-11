# frozen_string_literal: true

module Budget
  class AllocationsController < Budget::BaseController
    before_action :set_budget_year

    def create
      @allocation = @budget_year.budget_allocations.build(allocation_params)
      if @allocation.save
        redirect_to allocations_budget_year_path(@budget_year), notice: "Allocation added."
      else
        redirect_to allocations_budget_year_path(@budget_year), alert: @allocation.errors.full_messages.to_sentence
      end
    end

    def update
      @allocation = @budget_year.budget_allocations.find(params[:id])
      if @allocation.update(allocation_params)
        redirect_to allocations_budget_year_path(@budget_year), notice: "Allocation updated."
      else
        redirect_to allocations_budget_year_path(@budget_year), alert: @allocation.errors.full_messages.to_sentence
      end
    end

    private

    def set_budget_year
      @budget_year = Budget::Year.find(params[:year_id])
    end

    def allocation_params
      params.require(:budget_allocation).permit(:budget_category_id, :allocated_amount)
    end
  end
end
