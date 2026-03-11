# frozen_string_literal: true

module Budget
  class SponsorshipDealsController < Budget::BaseController
    before_action :set_sponsorship_deal

    def show
      @event = @sponsorship_deal.event
      @expenses = @sponsorship_deal.budget_expenses.includes(:budget_year, :budget_category).order(expense_date: :desc)
    end

    private

    def set_sponsorship_deal
      @sponsorship_deal = SponsorshipDeal.find(params[:id])
    end
  end
end
