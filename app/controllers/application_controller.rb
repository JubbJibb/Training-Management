class ApplicationController < ActionController::Base
  include Pundit::Authorization

  allow_browser versions: :modern
  stale_when_importmap_changes

  helper_method :current_user

  def current_user
    return nil unless session[:admin_user_id].present?
    @current_user ||= AdminUser.find_by(id: session[:admin_user_id])
  end

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized
    redirect_to(request.referer || root_path, alert: "You are not authorized to perform this action.")
  end
end
