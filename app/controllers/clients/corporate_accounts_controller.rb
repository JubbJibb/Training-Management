# frozen_string_literal: true

module Clients
  class CorporateAccountsController < Clients::BaseController
    def index
      @data = Clients::CorporateAccountsInsights.new(index_params).call
      @date_range = @data[:date_range]
    rescue StandardError => e
      Rails.logger.error("[CorporateAccounts] #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
      @data = { kpis: {}, accounts: [], at_risk_accounts: [], upcoming_unpaid_corporate: [] }
      @date_range = { start_date: Date.current.beginning_of_month, end_date: Date.current.end_of_month, preset: "mtd" }
      @load_error = e.message
    end

    def show
      @profile = Clients::CorporateAccountProfile.new(customer_id: params[:id], params: {}).call
      return redirect_to clients_corporate_accounts_path, alert: "Account not found" if @profile[:error]
      @account_name = @profile[:account_name]
    end

    private

    def index_params
      params.permit(:preset, :start_date, :end_date, :industry, :active, :has_overdue, :min_revenue).to_h
    end
  end
end
