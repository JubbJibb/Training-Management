# frozen_string_literal: true

module Admin
  # Executive Insights: consolidated performance & decision support.
  # Reuses dashboard/finance data where appropriate.
  class InsightsController < ApplicationController
    layout "admin"

    def index
      # Business Insights: reuse admin dashboard logic
      redirect_to admin_dashboard_index_path
    end

    def financial
      redirect_to financial_overview_path
    end

    def strategy
      redirect_to admin_settings_path
    end

    def actions
      # Action Center: reuse dashboard action-required queue
      redirect_to admin_dashboard_index_path(anchor: "action-required")
    end
  end
end
