module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user
  end

  private

  def authenticate_user
    user_id = request.headers["X-USER-ID"]

    if user_id.blank?
      render json: {
        error: "X-USER-ID header is required",
        error_code: "MISSING_USER_ID"
      }, status: :bad_request
      return
    end

    @current_user = User.find_by(id: user_id)

    if @current_user.nil?
      render json: {
        error: "User not found",
        error_code: "USER_NOT_FOUND"
      }, status: :not_found
      return
    end
  end

  def current_user
    @current_user
  end

  def require_authentication
    authenticate_user unless @current_user
  end
end
