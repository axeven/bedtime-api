class Api::V1::FollowersController < Api::V1::BaseController
  include QueryCountable

  before_action :authenticate_user

  def index
    limit = [params[:limit]&.to_i || 20, 100].min
    offset = params[:offset]&.to_i || 0

    # Use existing cached count from User model
    total_count = current_user.followers_count

    # Only cache small result sets (first page with default limit)
    should_cache = offset == 0 && limit <= 20

    if should_cache
      cache_key = CacheService.cache_key(:followers_list, current_user.id, "#{limit}_#{offset}")

      followers_data = CacheService.fetch(cache_key, expires_in: 30.minutes) do
        fetch_paginated_followers(limit, offset)
      end

      cached = Rails.cache.exist?(cache_key)
    else
      # Don't cache large offsets or large limits
      followers_data = fetch_paginated_followers(limit, offset)
      cached = false
      cache_key = 'not_cached'
    end

    render_success({
      followers: followers_data,
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

  private

  def fetch_paginated_followers(limit, offset)
    current_user.follower_relationships
                .includes(:user)
                .order(created_at: :desc)
                .limit(limit)
                .offset(offset)
                .map { |follow| serialize_follower(follow) }
  end

  def serialize_follower(follow)
    {
      id: follow.user.id,
      name: follow.user.name,
      followed_at: follow.created_at.iso8601
    }
  end
end