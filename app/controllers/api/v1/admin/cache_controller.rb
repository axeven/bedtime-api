class Api::V1::Admin::CacheController < Api::V1::BaseController
  # For development/admin use - could be protected with admin authentication in production
  skip_before_action :authenticate_user, only: [:stats, :clear, :warm, :debug]

  def stats
    cache_stats = CacheService.cache_stats

    # Additional debugging information
    redis_info = Rails.cache.redis.with { |redis| redis.info }

    render_success({
      cache_stats: cache_stats,
      redis_info: {
        version: redis_info['redis_version'],
        uptime_in_seconds: redis_info['uptime_in_seconds'],
        connected_clients: redis_info['connected_clients'],
        used_memory_human: redis_info['used_memory_human'],
        used_memory_peak_human: redis_info['used_memory_peak_human'],
        keyspace_hits: redis_info['keyspace_hits'],
        keyspace_misses: redis_info['keyspace_misses'],
        expired_keys: redis_info['expired_keys'],
        evicted_keys: redis_info['evicted_keys']
      },
      environment: Rails.env,
      cache_store: Rails.cache.class.name
    })
  end

  def clear
    pattern = params[:pattern]
    user_id = params[:user_id]

    if pattern.present?
      CacheService.delete_pattern(pattern)
      message = "Cleared cache pattern: #{pattern}"
    elsif user_id.present?
      # Clear CacheService patterns using constants
      pattern_names = [:following_list, :followers_list, :social_sleep_stats, :sleep_statistics]
      pattern_names.each { |pattern_name| CacheService.delete_user_pattern(pattern_name, user_id) }

      # Clear User model count caches using constants
      count_keys = [
        CacheService.cache_key(:following_count, user_id),
        CacheService.cache_key(:followers_count, user_id)
      ]
      count_keys.each { |key| Rails.cache.delete(key) }

      message = "Cleared all cache patterns and User model caches for user #{user_id}"
    else
      Rails.cache.clear
      message = "Cleared all cache data"
    end

    render_success({
      message: message,
      cache_stats: CacheService.cache_stats
    })
  end

  def warm
    user_id = params[:user_id]

    if user_id.present?
      user = User.find(user_id)
      CacheService.warm_user_cache(user)
      message = "Cache warmed for user #{user.id} (#{user.name})"
    else
      warmed_count = 0
      User.find_each do |user|
        CacheService.warm_user_cache(user)
        warmed_count += 1
      end
      message = "Cache warmed for #{warmed_count} users"
    end

    render_success({
      message: message,
      cache_stats: CacheService.cache_stats
    })
  end

  def debug
    user_id = params[:user_id]
    return render_error('user_id parameter required', 'MISSING_USER_ID', {}, :bad_request) unless user_id

    user = User.find(user_id)

    # Sample cache keys for this user using constants
    cache_keys = [
      CacheService.cache_key(:following_list, user.id, '20_0'),
      CacheService.cache_key(:followers_list, user.id, '20_0'),
      CacheService.cache_key(:social_sleep_stats, user.id, '7d_duration'),
      CacheService.cache_key(:sleep_statistics, user.id, '7_days')
    ]

    debug_info = cache_keys.map do |key|
      cached_data = Rails.cache.read(key)
      {
        key: key,
        exists: cached_data.present?,
        data_type: cached_data.class.name,
        data_size: cached_data.respond_to?(:size) ? cached_data.size : 'unknown'
      }
    end

    render_success({
      user_id: user.id,
      user_name: user.name,
      cache_debug: debug_info,
      cache_stats: CacheService.cache_stats
    })
  end
end