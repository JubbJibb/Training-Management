# frozen_string_literal: true

module Financials
  class ExpensesController < Financials::BaseController
    def index
      @expenses_by_class = Financials::ExpensesByClassQuery.call(filter_params)
      @category_totals = Financials::ExpenseCategoryTotalsQuery.call(filter_params)
      @expense_rows = expense_flat_rows
      @expense_kpis = expense_kpis
    end

    private

    def filter_params
      params.permit(:period, :date_from, :date_to, :client_type, :status).to_h.symbolize_keys
    end

    def expense_flat_rows
      resolver = Financials::DateRangeResolver.new(filter_params)
      ClassExpense.joins(:training_class)
        .where(training_classes: { date: resolver.start_date..resolver.end_date })
        .includes(:training_class)
        .order("training_classes.date DESC", "class_expenses.id DESC")
        .map do |e|
          {
            date: e.training_class.date,
            class_title: e.training_class.title,
            training_class_id: e.training_class_id,
            category: e.category.presence || "—",
            amount: e.amount,
            note: e.description,
            id: e.id
          }
        end
    end

    def expense_kpis
      total = @expense_rows.sum { |r| r[:amount].to_f }
      num_classes = @expenses_by_class.size
      avg = num_classes.positive? ? (total / num_classes).round(2) : 0
      top = @category_totals.first
      {
        total: total,
        avg_per_class: avg,
        top_category: top ? "#{top[:category]} ฿#{top[:total].to_i}" : "—"
      }
    end
  end
end
