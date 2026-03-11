# frozen_string_literal: true

module Budget
  class OverviewController < Budget::BaseController
    def index
      @budget_years = Budget::Year.by_year
      @budget_year = if params[:year_id].present?
        Budget::Year.find_by(id: params[:year_id])
      else
        Budget::Year.current
      end
      if @budget_year
        @summary = Budget::Summary.totals_for_year(@budget_year)
        @by_category = Budget::Summary.by_category_for_year(@budget_year)
        @monthly_trend = Budget::Summary.monthly_trend(@budget_year)
        @alerts = Budget::Summary.alerts(@budget_year, threshold: 0.8)
      end
    end
  end
end
