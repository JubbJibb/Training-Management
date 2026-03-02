# frozen_string_literal: true

module Financials
  class ExportHistoryController < Financials::BaseController
    def index
      @exports = Financials::ExportHistoryQuery.call(filter_params)
    end

    private

    def filter_params
      params.permit(:period, :date_from, :date_to, :status).to_h.symbolize_keys
    end
  end
end
