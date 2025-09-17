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
      # Invalidate cache after successful follow
      invalidate_follow_caches(current_user, following_user)

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

    # Use existing cached count from User model
    total_count = current_user.following_count

    # Only cache small result sets (first page with default limit)
    should_cache = offset == 0 && limit <= 20

    if should_cache
      cache_key = CacheService.cache_key(:following_list, current_user.id, "#{limit}_#{offset}")

      following_data = CacheService.fetch(cache_key, expires_in: 30.minutes) do
        fetch_paginated_following(limit, offset)
      end

      cached = Rails.cache.exist?(cache_key)
    else
      # Don't cache large offsets or large limits
      following_data = fetch_paginated_following(limit, offset)
      cached = false
      cache_key = 'not_cached'
    end

    render_success({
      following: following_data,
      pagination: {
        total_count: total_count,
        limit: limit,
        offset: offset,
        has_more: (offset + limit) < total_count
      },
      cache_info: {
        cached: cached,
        cache_key: cache_key
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
    # Invalidate cache after successful unfollow
    invalidate_follow_caches(current_user, following_user)
    head :no_content
  end

  private

  def fetch_paginated_following(limit, offset)
    current_user.follows
                .includes(:following_user)
                .order(created_at: :desc)
                .limit(limit)
                .offset(offset)
                .map { |follow| serialize_follow(follow) }
  end

  def serialize_follow(follow)
    {
      id: follow.following_user.id,
      name: follow.following_user.name,
      followed_at: follow.created_at.iso8601
    }
  end

  def invalidate_follow_caches(follower, following_user)
    # Invalidate follower's following list cache
    CacheService.delete_user_pattern(:following_list, follower.id)

    # Invalidate following_user's followers list cache
    CacheService.delete_user_pattern(:followers_list, following_user.id)

    # Invalidate social sleep statistics that might be affected
    CacheService.delete_user_pattern(:sleep_statistics, follower.id)

    # Note: User model count caches are invalidated by Follow model callbacks
  end

  def follow_params
    params.permit(:following_user_id)
  end
end