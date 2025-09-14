class Api::V1::FollowsController < Api::V1::BaseController
  before_action :authenticate_user

  def create
    following_user = User.find_by(id: follow_params[:following_user_id])

    unless following_user
      render_error(
        'User not found',
        'USER_NOT_FOUND',
        {},
        :not_found
      )
      return
    end

    if current_user.id == following_user.id
      render_error(
        'Cannot follow yourself',
        'SELF_FOLLOW_NOT_ALLOWED',
        {},
        :unprocessable_entity
      )
      return
    end

    follow = current_user.follows.build(following_user: following_user)

    if follow.save
      render_success({
        id: follow.id,
        following_user_id: follow.following_user_id,
        following_user_name: following_user.name,
        created_at: follow.created_at.iso8601
      }, :created)
    else
      if follow.errors[:user_id]&.include?('has already been taken')
        render_error(
          'Already following this user',
          'DUPLICATE_FOLLOW',
          {},
          :unprocessable_entity
        )
      else
        render_validation_error(follow)
      end
    end
  end

  private

  def follow_params
    params.permit(:following_user_id)
  end
end