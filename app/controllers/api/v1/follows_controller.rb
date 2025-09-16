class Api::V1::FollowsController < Api::V1::BaseController
  include QueryCountable

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

  def index
    limit = [params[:limit]&.to_i || 20, 100].min
    offset = params[:offset]&.to_i || 0

    follows = current_user.follows
                         .includes(:following_user)
                         .order(created_at: :desc)
                         .limit(limit)
                         .offset(offset)

    total_count = current_user.follows.count

    following_users = follows.map do |follow|
      {
        id: follow.following_user.id,
        name: follow.following_user.name,
        followed_at: follow.created_at.iso8601
      }
    end

    render_success({
      following: following_users,
      pagination: {
        total_count: total_count,
        limit: limit,
        offset: offset,
        has_more: (offset + limit) < total_count
      }
    })
  end

  def destroy
    following_user = User.find_by(id: params[:id])

    unless following_user
      render_error(
        'User not found',
        'USER_NOT_FOUND',
        {},
        :not_found
      )
      return
    end

    follow = current_user.follows.find_by(following_user: following_user)

    unless follow
      render_error(
        'Not following this user',
        'FOLLOW_RELATIONSHIP_NOT_FOUND',
        {},
        :not_found
      )
      return
    end

    follow.destroy
    head :no_content
  end

  private

  def follow_params
    params.permit(:following_user_id)
  end
end