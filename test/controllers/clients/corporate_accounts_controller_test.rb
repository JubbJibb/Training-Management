# frozen_string_literal: true

require "test_helper"

module Clients
  class CorporateAccountsControllerTest < ActionDispatch::IntegrationTest
    test "should get index" do
      get clients_corporate_accounts_url
      assert_response :success
    end

    test "should get show when customer exists" do
      c = Customer.first
      get clients_corporate_account_url(c.id) if c
      if c
        assert_response :success
      else
        get clients_corporate_account_url(1)
        assert_redirected_to clients_corporate_accounts_path
      end
    end

    test "show redirects when account not found" do
      get clients_corporate_account_url(999999)
      assert_redirected_to clients_corporate_accounts_path
    end
  end
end
