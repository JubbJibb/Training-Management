# frozen_string_literal: true

module Financials
  class ExportHistoryQuery
    class << self
      def call(params = {})
        new(params).call
      end
    end

    def initialize(params = {})
      @params = params
      @resolver = Financials::DateRangeResolver.new(params)
    end

    def call
      scope = ExportJob.order(created_at: :desc)
      scope = scope.where(state: @params[:status]) if @params[:status].present?
      if @params[:period].present? || @params[:date_from].present?
        range = @resolver.start_date.beginning_of_day..@resolver.end_date.end_of_day
        scope = scope.where(created_at: range)
      end
      scope.includes(:requested_by).limit(200).to_a
    end
  end
end
