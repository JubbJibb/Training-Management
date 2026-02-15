# frozen_string_literal: true

module Financials
  class PaymentTrackingController < Financials::BaseController
    def index
      redirect_to finance_payments_path
    end
  end
end
