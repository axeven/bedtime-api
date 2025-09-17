namespace :cache do
  desc "Warm up critical cache data for all users"
  task warm_all: :environment do
    puts "Starting cache warm-up for all users..."

    total_users = User.count
    warmed_count = 0

    User.find_each do |user|
      CacheService.warm_user_cache(user)
      warmed_count += 1

      if warmed_count % 10 == 0
        puts "Warmed cache for #{warmed_count}/#{total_users} users"
      end
    end

    puts "Cache warm-up completed for #{warmed_count} users"
    puts "Cache stats: #{CacheService.cache_stats}"
  end

  desc "Warm up cache for specific user"
  task :warm_user, [ :user_id ] => :environment do |t, args|
    user_id = args[:user_id]

    if user_id.blank?
      puts "Usage: bundle exec rake cache:warm_user[USER_ID]"
      exit 1
    end

    user = User.find(user_id)
    puts "Warming cache for user #{user.id} (#{user.name})"

    CacheService.warm_user_cache(user)

    puts "Cache warmed successfully"
    puts "Cache stats: #{CacheService.cache_stats}"
  end

  desc "Clear all cache data"
  task clear_all: :environment do
    puts "Clearing all cache data..."

    Rails.cache.clear

    puts "All cache data cleared"
    puts "Cache stats: #{CacheService.cache_stats}"
  end

  desc "Show cache statistics"
  task stats: :environment do
    puts "Cache Statistics:"
    puts "=================="
    stats = CacheService.cache_stats

    stats.each do |key, value|
      puts "#{key.to_s.humanize}: #{value}"
    end
  end

  desc "Clear cache patterns for specific user"
  task :clear_user, [ :user_id ] => :environment do |t, args|
    user_id = args[:user_id]

    if user_id.blank?
      puts "Usage: bundle exec rake cache:clear_user[USER_ID]"
      exit 1
    end

    user = User.find(user_id)
    puts "Clearing cache for user #{user.id} (#{user.name})"

    # Clear CacheService patterns using constants
    pattern_names = [ :following_list, :followers_list, :social_sleep_stats, :sleep_statistics ]

    pattern_names.each do |pattern_name|
      CacheService.delete_user_pattern(pattern_name, user.id)
      puts "Cleared pattern: #{pattern_name} for user #{user.id}"
    end

    # Clear User model count caches using constants
    count_keys = [
      CacheService.cache_key(:following_count, user.id),
      CacheService.cache_key(:followers_count, user.id)
    ]

    count_keys.each do |key|
      Rails.cache.delete(key)
      puts "Cleared User cache key: #{key}"
    end

    puts "User cache cleared successfully"
  end

  desc "Performance benchmark for cache operations"
  task benchmark: :environment do
    require "benchmark"

    puts "Cache Performance Benchmark"
    puts "=========================="

    user = User.first || User.create!(name: "Cache Test User")

    # Test cache write performance using following_list pattern
    write_time = Benchmark.measure do
      1000.times do |i|
        key = CacheService.cache_key(:following_list, user.id, "benchmark_#{i}")
        CacheService.fetch(key, expires_in: 1.minute) { "test_data_#{i}" }
      end
    end

    puts "Cache Write (1000 operations): #{write_time.real.round(3)}s"

    # Test cache read performance
    read_time = Benchmark.measure do
      1000.times do |i|
        key = CacheService.cache_key(:following_list, user.id, "benchmark_#{i}")
        Rails.cache.read(key)
      end
    end

    puts "Cache Read (1000 operations): #{read_time.real.round(3)}s"

    # Test pattern deletion performance
    delete_time = Benchmark.measure do
      CacheService.delete_user_pattern(:following_list, user.id)
    end

    puts "Pattern Delete (1000 keys): #{delete_time.real.round(3)}s"

    puts "\nCache Stats After Benchmark:"
    puts CacheService.cache_stats
  end
end
