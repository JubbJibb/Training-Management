# frozen_string_literal: true

module Budget
  class Summary
    def self.totals_for_year(budget_year)
      new(budget_year).totals_for_year
    end

    def self.totals_for_month(budget_year, month)
      new(budget_year).totals_for_month(month)
    end

    def self.by_category_for_year(budget_year)
      new(budget_year).by_category_for_year
    end

    def self.by_category_for_month(budget_year, month)
      new(budget_year).by_category_for_month(month)
    end

    def self.monthly_trend(budget_year)
      new(budget_year).monthly_trend
    end

    def self.alerts(budget_year, threshold: 0.8)
      new(budget_year).alerts(threshold)
    end

    def initialize(budget_year)
      @year = budget_year
      @expenses = budget_year.budget_expenses
    end

    def totals_for_year
      {
        paid: @expenses.paid.sum(:amount).to_f,
        committed: @expenses.committed.sum(:amount).to_f,
        planned: @expenses.planned.sum(:amount).to_f,
        total_spend: @expenses.sum(:amount).to_f,
        total_budget: @year.total_budget.to_f,
        remaining: (@year.total_budget.to_f - @expenses.sum(:amount).to_f).round(2)
      }
    end

    def totals_for_month(month)
      scope = expenses_in_month(month)
      {
        paid: scope.paid.sum(:amount).to_f,
        committed: scope.committed.sum(:amount).to_f,
        planned: scope.planned.sum(:amount).to_f,
        total: scope.sum(:amount).to_f
      }
    end

    def by_category_for_year
      categories = @year.budget_allocations.includes(:budget_category).map do |alloc|
        cat = alloc.budget_category
        expenses_scope = @expenses.where(budget_category_id: cat.id)
        paid = expenses_scope.paid.sum(:amount).to_f
        committed = expenses_scope.committed.sum(:amount).to_f
        planned = expenses_scope.planned.sum(:amount).to_f
        total = paid + committed + planned
        allocated = alloc.allocated_amount.to_f
        remaining = allocated - total
        pct = allocated.positive? ? ((total / allocated) * 100).round(1) : 0
        over = total > allocated
        {
          category: cat,
          allocation: alloc,
          allocated: allocated,
          paid: paid,
          committed: committed,
          planned: planned,
          total: total,
          remaining: remaining.round(2),
          usage_pct: pct,
          over: over
        }
      end
      categories.sort_by { |c| c[:category].sort_order.to_i }
    end

    def by_category_for_month(month)
      scope = expenses_in_month(month)
      by_cat = scope.group_by(&:budget_category_id)
      @year.budget_allocations.includes(:budget_category).map do |alloc|
        cat = alloc.budget_category
        list = by_cat[cat.id] || []
        paid = list.select { |e| e.payment_status == "paid" }.sum(&:amount).to_f
        committed = list.select { |e| e.payment_status == "committed" }.sum(&:amount).to_f
        planned = list.select { |e| e.payment_status == "planned" }.sum(&:amount).to_f
        {
          category: cat,
          paid: paid,
          committed: committed,
          planned: planned,
          total: paid + committed + planned
        }
      end.sort_by { |c| c[:category].sort_order.to_i }
    end

    def monthly_trend
      (1..12).map do |m|
        scope = expenses_in_month(m)
        {
          month: m,
          label: Date::MONTHNAMES[m],
          paid: scope.paid.sum(:amount).to_f,
          committed: scope.committed.sum(:amount).to_f,
          planned: scope.planned.sum(:amount).to_f,
          total: scope.sum(:amount).to_f
        }
      end
    end

    # threshold: 0.8 = 80%. Returns categories over threshold, over budget, and high-level risks.
    def alerts(threshold = 0.8)
      by_cat = by_category_for_year
      over_threshold = by_cat.select { |r| r[:usage_pct].to_f >= (threshold * 100) && !r[:over] }
      over_budget = by_cat.select { |r| r[:over] }
      {
        over_threshold: over_threshold,
        over_budget: over_budget,
        any?: (over_threshold.any? || over_budget.any?)
      }
    end

    private

    def expenses_in_month(month)
      m = month.to_i
      m = [[m, 1].max, 12].min
      start_date = Date.new(@year.year, m, 1)
      end_date = start_date.end_of_month
      @expenses.where(expense_date: start_date..end_date)
    end
  end
end
