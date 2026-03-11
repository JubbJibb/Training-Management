# frozen_string_literal: true

module Budget
  class SetupController < Budget::BaseController
    def index
      @budget_years = Budget::Year.by_year
      @budget_categories = Budget::Category.ordered
      @selected_year = if params[:year_id].present?
        Budget::Year.find_by(id: params[:year_id])
      else
        Budget::Year.current || @budget_years.first
      end
      if @selected_year
        @allocations = @selected_year.budget_allocations.includes(:budget_category).order("budget_categories.sort_order")
      end
    end
  end
end
