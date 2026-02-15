# frozen_string_literal: true

module Insights
  class ActionsController < Insights::BaseController
    def index
      @data = safe_action_data
      @filter_params = filter_params
    end

    private

    def safe_action_data
      Insights::ActionCenter.new(params.permit(:filter)).call
    rescue StandardError
      { critical: [], warning: [], follow_up: [], task_queue: [] }
    end

    def filter_params
      {
        filter: params[:filter].presence || "all",
        critical_only: params[:critical_only],
        finance_only: params[:finance_only],
        client_only: params[:client_only]
      }
    end
  end
end
