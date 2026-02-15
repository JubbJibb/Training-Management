# frozen_string_literal: true

module Admin
  # Expense Control: list class expenses across training classes (Financials > Expense Control).
  class ExpensesController < ApplicationController
    layout "admin"

    def index
      @expenses = ClassExpense.includes(:training_class)
                              .order(created_at: :desc)
                              .limit(100)
      @total_amount = @expenses.sum(:amount)
    end
  end
end
