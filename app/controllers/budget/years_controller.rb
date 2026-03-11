# frozen_string_literal: true

module Budget
  class YearsController < Budget::BaseController
    before_action :set_budget_year, only: [:show, :allocations, :expenses, :expenses_list, :monthly]

    def index
      @budget_years = Budget::Year.by_year
    end

    def show
      @summary = Budget::Summary.totals_for_year(@budget_year)
      @by_category = Budget::Summary.by_category_for_year(@budget_year)
      @monthly_trend = Budget::Summary.monthly_trend(@budget_year)
    end

    def new
      @budget_year = Budget::Year.new(year: Date.current.year, status: "draft")
    end

    def create
      @budget_year = Budget::Year.new(budget_year_params)
      if @budget_year.save
        redirect_to budget_year_path(@budget_year), notice: "Budget year created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def redirect_to_current
      current = Budget::Year.current
      if current
        redirect_to budget_year_path(current), status: :found
      else
        redirect_to budget_years_path, notice: "No active budget year. Create one first."
      end
    end

    def allocations
      @allocations = @budget_year.budget_allocations.includes(:budget_category).order("budget_categories.sort_order")
      @budget_categories = Budget::Category.ordered
    end

    def expenses_list
      @expenses = @budget_year.budget_expenses.includes(:budget_category, :sponsorship_deal)
      @expenses = apply_expense_filters(@expenses)
      @expenses = @expenses.order(expense_date: :desc)
      render "budget/years/expenses_list", layout: false
    end

    def expenses
      @expenses = @budget_year.budget_expenses.includes(:budget_category, :sponsorship_deal)
      @expenses = apply_expense_filters(@expenses)
      @expenses = @expenses.order(expense_date: :desc)
    end

    def monthly
      @month = (params[:month].presence || Date.current.month).to_i
      @month = [[@month, 1].max, 12].min
      @summary_month = Budget::Summary.totals_for_month(@budget_year, @month)
      @by_category_month = Budget::Summary.by_category_for_month(@budget_year, @month)
      start_date = Date.new(@budget_year.year, @month, 1)
      end_date = start_date.end_of_month
      @expenses_month = @budget_year.budget_expenses.in_date_range(start_date, end_date).includes(:budget_category).order(expense_date: :desc)
    end

    private

    def set_budget_year
      @budget_year = Budget::Year.find(params[:id])
    end

    def budget_year_params
      params.require(:budget_year).permit(:year, :total_budget, :status, :owner_name, :notes)
    end

    def apply_expense_filters(scope)
      scope = scope.where(payment_status: params[:status]) if params[:status].present?
      scope = scope.where(budget_category_id: params[:category_id]) if params[:category_id].present?
      if params[:month].present?
        m = params[:month].to_i
        m = [[m, 1].max, 12].min
        start_date = Date.new(@budget_year.year, m, 1)
        end_date = start_date.end_of_month
        scope = scope.where(expense_date: start_date..end_date)
      end
      scope = scope.where("vendor LIKE ?", "%#{params[:vendor]}%") if params[:vendor].present?
      scope = scope.where(sponsorship_deal_id: params[:sponsorship_deal_id]) if params[:sponsorship_deal_id].present?
      if params[:date_from].present?
        from = Date.parse(params[:date_from]) rescue nil
        scope = scope.where("expense_date >= ?", from) if from
      end
      if params[:date_to].present?
        to = Date.parse(params[:date_to]) rescue nil
        scope = scope.where("expense_date <= ?", to) if to
      end
      scope
    end
  end
end
