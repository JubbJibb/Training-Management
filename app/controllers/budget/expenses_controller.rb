# frozen_string_literal: true

module Budget
  class ExpensesController < Budget::BaseController
    before_action :set_budget_year, only: [:new, :create]

    def new
      @budget_year = Budget::Year.find(params[:year_id]) if params[:year_id].present?
      return redirect_to budget_years_path, alert: "Missing year." unless @budget_year
      @expense = @budget_year.budget_expenses.build(
        expense_date: Date.current,
        payment_status: "planned",
        sponsorship_deal_id: params[:sponsorship_deal_id]
      )
      @budget_categories = Budget::Category.ordered
    end

    def create
      @budget_year = Budget::Year.find(params[:year_id])
      @expense = @budget_year.budget_expenses.build(expense_params)
      @budget_categories = Budget::Category.ordered
      if @expense.save
        redirect_to expenses_budget_year_path(@budget_year), notice: "Expense created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      set_expense
      @budget_categories = Budget::Category.ordered
    end

    def update
      set_expense
      if @expense.update(expense_params)
        redirect_to expenses_budget_year_path(@expense.budget_year), notice: "Expense updated."
      else
        @budget_categories = Budget::Category.ordered
        render :edit, status: :unprocessable_entity
      end
    end

    def mark_paid
      set_expense
      if @expense.update(payment_status: "paid")
        redirect_to request.referer || budget_year_expenses_path(@expense.budget_year), notice: "Marked as paid."
      else
        redirect_to request.referer || budget_year_expenses_path(@expense.budget_year), alert: @expense.errors.full_messages.to_sentence
      end
    end

    private

    def set_budget_year
      @budget_year = Budget::Year.find(params[:year_id]) if params[:year_id].present?
    end

    def set_expense
      @expense = Budget::Expense.find(params[:id])
    end

    def expense_params
      params.require(:budget_expense).permit(
        :budget_category_id, :amount, :expense_date, :vendor, :reference_no,
        :payment_status, :payment_method, :notes, :class_id, :campaign_id, :sponsorship_deal_id
      )
    end
  end
end
