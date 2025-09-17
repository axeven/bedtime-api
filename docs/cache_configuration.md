# Cache Configuration Reference

This document provides a centralized view of all cache patterns and expiration times for easy management.

## Cache Key Patterns

All cache key patterns are defined in `CacheService::CACHE_PATTERNS`:

```ruby
CACHE_PATTERNS = {
  following_list: 'following_list:user:%{user_id}:%{suffix}',
  followers_list: 'followers_list:user:%{user_id}:%{suffix}',
  following_count: 'user:%{user_id}:following_count',
  followers_count: 'user:%{user_id}:followers_count',
  social_sleep_stats: 'social_sleep_stats:user:%{user_id}:%{suffix}',
  sleep_statistics: 'sleep_statistics:user:%{user_id}:%{suffix}'
}
```

## Pattern Deletion Prefixes

For bulk deletion operations, patterns are defined in `CacheService::CACHE_PREFIXES`:

```ruby
CACHE_PREFIXES = {
  following_list: 'following_list:user:%{user_id}:*',
  followers_list: 'followers_list:user:%{user_id}:*',
  social_sleep_stats: 'social_sleep_stats:user:%{user_id}:*',
  sleep_statistics: 'sleep_statistics:user:%{user_id}:*'
}
```

## Expiration Times

All cache expiration times are centralized in `CacheService::EXPIRATION_TIMES`:

| Cache Type | Expiration | Reason |
|------------|------------|---------|
| `following_list` | 1 hour | Social lists change infrequently |
| `followers_list` | 1 hour | Social lists change infrequently |
| `following_count` | 1 hour | Counts change infrequently |
| `followers_count` | 1 hour | Counts change infrequently |
| `sleep_statistics` | 30 minutes | Expensive calculations, medium frequency |
| `social_sleep_records` | 5 minutes | Social feed needs freshness |

## Usage Examples

### Creating Cache Keys
```ruby
# List with pagination
CacheService.cache_key(:following_list, user.id, '20_0')
# → "following_list:user:123:20_0"

# Count cache
CacheService.cache_key(:following_count, user.id)
# → "user:123:following_count"

# Statistics with parameters
CacheService.cache_key(:social_sleep_stats, user.id, '7d_duration')
# → "social_sleep_stats:user:123:7d_duration"
```

### Pattern Deletion
```ruby
# Delete all following lists for a user
CacheService.delete_user_pattern(:following_list, user.id)
# Deletes: "following_list:user:123:*"

# Delete multiple patterns
[:following_list, :followers_list, :sleep_statistics].each do |pattern|
  CacheService.delete_user_pattern(pattern, user.id)
end
```

### Using Expiration Times
```ruby
# In controllers
CacheService.fetch(cache_key, expires_in: CacheService::EXPIRATION_TIMES[:following_list]) do
  # expensive operation
end

# In models (User count methods)
Rails.cache.fetch(key, expires_in: CacheService::EXPIRATION_TIMES[:followers_count]) do
  follower_relationships.count
end
```

## Cache Strategy Summary

### What Gets Cached:
- **Following/Followers Lists**: Only first page (≤20 items, offset=0)
- **Count Queries**: All count operations (cheap to cache)
- **Social Statistics**: Expensive aggregations with parameters
- **Sleep Statistics**: User-specific sleep data calculations

### What Doesn't Get Cached:
- **Large Lists**: limit >20 or offset >0
- **Deep Pagination**: Beyond first page
- **Real-time Data**: Active sleep sessions
- **User-specific Data**: Cross-user queries

### Cache Invalidation:
- **Automatic**: Model callbacks invalidate related caches
- **Manual**: Admin tools and rake tasks for debugging
- **Pattern-based**: Bulk invalidation using wildcard patterns

## Adding New Cache Types

To add a new cache type:

1. **Add pattern to `CACHE_PATTERNS`**:
   ```ruby
   new_cache_type: 'new_cache:user:%{user_id}:%{suffix}'
   ```

2. **Add deletion prefix to `CACHE_PREFIXES`**:
   ```ruby
   new_cache_type: 'new_cache:user:%{user_id}:*'
   ```

3. **Add expiration time to `EXPIRATION_TIMES`**:
   ```ruby
   new_cache_type: 15.minutes
   ```

4. **Use in code**:
   ```ruby
   cache_key = CacheService.cache_key(:new_cache_type, user.id, 'params')
   CacheService.fetch(cache_key, expires_in: CacheService::EXPIRATION_TIMES[:new_cache_type]) do
     # expensive operation
   end
   ```

## Monitoring and Debugging

### Admin Endpoints:
- `GET /api/v1/admin/cache/stats` - Redis statistics
- `GET /api/v1/admin/cache/debug?user_id=X` - User-specific cache inspection
- `POST /api/v1/admin/cache/clear?user_id=X` - Clear user caches
- `POST /api/v1/admin/cache/warm?user_id=X` - Warm user caches

### Rake Tasks:
- `bundle exec rake cache:stats` - Show cache statistics
- `bundle exec rake cache:warm_user[USER_ID]` - Warm specific user
- `bundle exec rake cache:clear_user[USER_ID]` - Clear specific user
- `bundle exec rake cache:benchmark` - Performance testing

This centralized configuration makes cache management much easier and less error-prone!