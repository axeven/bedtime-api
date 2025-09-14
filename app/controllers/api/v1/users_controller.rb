class Api::V1::UsersController < Api::V1::BaseController
  skip_before_action :authenticate_user, only: [ :create ]

  def create
    # Optional: Restrict to development/test environments
    unless Rails.env.development? || Rails.env.test?
      render json: {
        error: "Endpoint not available in production",
        error_code: "FORBIDDEN"
      }, status: :forbidden
      return
    end

    user = User.new(user_params)

    if user.save
      render json: {
        id: user.id,
        name: user.name,
        created_at: user.created_at.iso8601
      }, status: :created
    else
      render_validation_error(user)
    end
  end

  private

  def user_params
    params.require(:user).permit(:name)
  end
end
