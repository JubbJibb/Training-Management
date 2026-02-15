# frozen_string_literal: true

module Clients
  class AnalysisController < Clients::BaseController
    def show
      @data = Clients::ClientAnalysis.new(analysis_params).call
      @date_range = @data[:date_range]
    end

    private

    def analysis_params
      params.permit(:preset, :start_date, :end_date, :client_type, :channel, :min_revenue).to_h
    end
  end
end
