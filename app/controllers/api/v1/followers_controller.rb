class Api::V1::FollowersController < Api::V1::BaseController
  before_action :authenticate_user

  def index
    limit = [params[:limit]&.to_i || 20, 100].min
    offset = params[:offset]&.to_i || 0

    follower_relationships = current_user.follower_relationships
                                        .includes(:user)
                                        .order(created_at: :desc)
                                        .limit(limit)
                                        .offset(offset)

    total_count = current_user.follower_relationships.count

    followers = follower_relationships.map do |follow|
      {
        id: follow.user.id,
        name: follow.user.name,
        followed_at: follow.created_at.iso8601
      }
    end

    render_success({
      followers: followers,
      pagination: {
        total_count: total_count,
        limit: limit,
        offset: offset,
        has_more: (offset + limit) < total_count
      }
    })
  end
end