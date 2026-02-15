# frozen_string_literal: true

module Clients
  class CorporateAccountsController < Clients::BaseController
    def index
      @data = Clients::CorporateAccountsInsights.new(index_params).call
      @date_range = @data[:date_range]
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
