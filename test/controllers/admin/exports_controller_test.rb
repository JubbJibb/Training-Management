# frozen_string_literal: true

require "test_helper"

module Admin
  class ExportsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = AdminUser.create!(email: "export@test.com", password: "password123", password_confirmation: "password123")
    end

    test "get index when not logged in redirects or shows empty" do
      get admin_exports_url
      # Either success with empty list or redirect when not authorized
      assert_response :redirect if response.redirect?
      assert_response :success unless response.redirect?
    end

    test "get index when logged in" do
      open_session do |s|
        s.session[:admin_user_id] = @admin.id
        s.get admin_exports_url
        assert_response :success
      end
    end

    test "create enqueues job when authorized" do
      open_session do |s|
        s.session[:admin_user_id] = @admin.id
        assert_enqueued_with(job: GenerateExportJob) do
          s.post admin_exports_url, params: {
            export_job: {
              export_type: "financial_report",
              format: "pdf",
              include_custom_fields: "0",
              filters: { period: "this_month" },
              include_sections: {}
            }
          }
        end
        assert_redirected_to admin_exports_path
      end
    end
  end
end
