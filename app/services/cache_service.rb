class CacheService
  # Cache key patterns for easy management
  CACHE_PATTERNS = {
    following_list: 'following_list:user:%{user_id}:%{suffix}',
    followers_list: 'followers_list:user:%{user_id}:%{suffix}',
    following_count: 'user:%{user_id}:following_count',
    followers_count: 'user:%{user_id}:followers_count',
    social_sleep_stats: 'social_sleep_stats:user:%{user_id}:%{suffix}',
    sleep_statistics: 'sleep_statistics:user:%{user_id}:%{suffix}'
  }.freeze

  # Cache key prefixes for pattern deletion
  CACHE_PREFIXES = {
    following_list: 'following_list:user:%{user_id}:*',
    followers_list: 'followers_list:user:%{user_id}:*',
    social_sleep_stats: 'social_sleep_stats:user:%{user_id}:*',
    sleep_statistics: 'sleep_statistics:user:%{user_id}:*'
  }.freeze

  EXPIRATION_TIMES = {
    following_list: 1.hour,
    followers_list: 1.hour,
    following_count: 1.hour,
    followers_count: 1.hour,
    sleep_statistics: 30.minutes,
    social_sleep_records: 5.minutes
  }.freeze

  def self.fetch(key, expires_in: 1.hour, &block)
    Rails.cache.fetch(key, expires_in: expires_in, &block)
  end

  def self.delete(key)
    Rails.cache.delete(key)
  end

  def self.delete_pattern(pattern)
    # Use Redis scan to find matching keys and delete them
    Rails.cache.redis.with do |redis|
      cursor = "0"
      begin
        cursor, keys = redis.scan(cursor, match: pattern)
        redis.del(*keys) if keys.any?
      end while cursor != "0"
    end
  rescue => e
    Rails.logger.error "Cache pattern deletion error: #{e.message}"
  end

  def self.cache_key(pattern_name, user_id, suffix = nil)
    pattern = CACHE_PATTERNS[pattern_name.to_sym]
    raise ArgumentError, "Unknown cache pattern: #{pattern_name}" unless pattern

    if suffix
      pattern % { user_id: user_id, suffix: suffix }
    else
      # For patterns without suffix, remove the suffix part
      base_pattern = pattern.gsub(':%{suffix}', '')
      base_pattern % { user_id: user_id }
    end
  end

  def self.delete_user_pattern(pattern_name, user_id)
    prefix = CACHE_PREFIXES[pattern_name.to_sym]
    raise ArgumentError, "Unknown cache prefix pattern: #{pattern_name}" unless prefix

    delete_pattern(prefix % { user_id: user_id })
  end

  # Cache warming for critical data
  def self.warm_user_cache(user)
    warm_following_cache(user)
    warm_followers_cache(user)
    warm_sleep_statistics_cache(user)
  end

  # Stats for cache monitoring
  def self.cache_stats
    info = Rails.cache.redis.with { |redis| redis.info }
    {
      connected_clients: info["connected_clients"],
      used_memory: info["used_memory_human"],
      used_memory_peak: info["used_memory_peak_human"],
      keyspace_hits: info["keyspace_hits"],
      keyspace_misses: info["keyspace_misses"],
      hit_rate: calculate_hit_rate(info["keyspace_hits"], info["keyspace_misses"])
    }
  rescue => e
    Rails.logger.error "Cache stats error: #{e.message}"
    { error: e.message }
  end

  private

  def self.warm_following_cache(user)
    # Only warm first page cache (most commonly accessed)
    # Count is handled by User model's following_count method
    list_key = cache_key(:following_list, user.id, '20_0')
    fetch(list_key, expires_in: 30.minutes) do
      user.follows.includes(:following_user)
          .order(created_at: :desc)
          .limit(20)
          .map do |follow|
        {
          id: follow.following_user.id,
          name: follow.following_user.name,
          followed_at: follow.created_at.iso8601
        }
      end
    end

    # Trigger User model count cache warming
    user.following_count
  end

  def self.warm_followers_cache(user)
    # Only warm first page cache (most commonly accessed)
    # Count is handled by User model's followers_count method
    list_key = cache_key(:followers_list, user.id, '20_0')
    fetch(list_key, expires_in: 30.minutes) do
      user.follower_relationships.includes(:user)
          .order(created_at: :desc)
          .limit(20)
          .map do |follow|
        {
          id: follow.user.id,
          name: follow.user.name,
          followed_at: follow.created_at.iso8601
        }
      end
    end

    # Trigger User model count cache warming
    user.followers_count
  end

  def self.warm_sleep_statistics_cache(user)
    key = cache_key(:sleep_statistics, user.id, '7_days')
    fetch(key, expires_in: EXPIRATION_TIMES[:sleep_statistics]) do
      calculate_sleep_statistics(user, 7.days.ago)
    end
  end

  def self.calculate_sleep_statistics(user, since)
    records = user.sleep_records.completed.where(bedtime: since..Time.current)
    durations = records.pluck(:duration_minutes).compact

    return {
      total_records: 0,
      average_duration: 0,
      total_sleep_time: 0,
      longest_sleep: 0,
      shortest_sleep: 0
    } if durations.empty?

    {
      total_records: records.count,
      average_duration: (durations.sum.to_f / durations.count).round(1),
      total_sleep_time: durations.sum,
      longest_sleep: durations.max,
      shortest_sleep: durations.min
    }
  end

  def self.calculate_hit_rate(hits, misses)
    hits = hits.to_i
    misses = misses.to_i
    total = hits + misses
    return 0.0 if total == 0
    ((hits.to_f / total) * 100).round(2)
  end
end