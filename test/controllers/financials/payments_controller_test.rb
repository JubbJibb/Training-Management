# frozen_string_literal: true

require "test_helper"

module Financials
  class PaymentsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @training_class = TrainingClass.create!(
        title: "Test Class",
        date: Date.current + 1.week,
        location: "Bangkok",
        price: 1000,
        cost: 0
      )
      @attendee = Attendee.create!(
        training_class: @training_class,
        name: "Test User",
        email: "test@example.com",
        participant_type: "Indi",
        seats: 1,
        payment_status: "Pending",
        status: "attendee"
      )
    end

    test "should get index with Payment Tracking table layout" do
      get financials_payments_url
      assert_response :success
      assert_select ".pt-page"
      assert_select ".pt-layout"
      assert_select ".pt-payments-table"
      assert_select "#pt-panel-wrap"
    end

    test "should get panel" do
      get panel_financials_payment_url(@attendee)
      assert_response :success
      assert_select ".pi-panel-content"
      assert_select ".pi-panel-section"
    end

    test "should get show" do
      get financials_payment_url(@attendee)
      assert_response :success
    end

    test "should get summary (HTML preview)" do
      get summary_financials_payment_url(@attendee)
      assert_response :success
      assert_select "h1", /Payment Summary/i
      assert_select "#payment-summary-content"
    end

    test "should get summary as PDF or redirect on error" do
      get summary_financials_payment_url(@attendee, format: :pdf)
      if response.successful?
        assert_equal "application/pdf", response.media_type, "Expected PDF when requesting .pdf format"
        assert response.body.start_with?("%PDF"), "Response should be PDF content" if response.media_type == "application/pdf"
      else
        assert_redirected_to summary_financials_payment_path(@attendee)
      end
    end

    test "should redirect to payment tracking when payment not found" do
      get financials_payment_url(id: 999999)
      assert_redirected_to financials_payments_path
    end
  end
end
