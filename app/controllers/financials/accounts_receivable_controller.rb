# frozen_string_literal: true

module Financials
  class AccountsReceivableController < Financials::BaseController
    def index
      @aging = Financials::ArAgingQuery.call(filter_params)
      @rows = Financials::ArByCustomerQuery.call(filter_params)
      @ar_items = Financials::ArByAttendeeQuery.call(filter_params)
    end

    private

    def filter_params
      params.permit(:period, :date_from, :date_to, :client_type, :status, :overdue_only).to_h.symbolize_keys
    end
  end
end
