# Performance testing utilities for benchmarking and query analysis
module PerformanceHelper
  extend self

  # Benchmark a block of code and return timing information
  def benchmark_query(description, &block)
    start_time = Time.current
    result = yield
    end_time = Time.current
    duration = ((end_time - start_time) * 1000).round(2)

    Rails.logger.info "BENCHMARK [#{description}]: #{duration}ms"

    {
      result: result,
      duration_ms: duration,
      description: description
    }
  end

  # Analyze a query using EXPLAIN ANALYZE
  def analyze_query(query)
    if query.respond_to?(:to_sql)
      sql = query.to_sql
    else
      sql = query.to_s
    end

    explained = ActiveRecord::Base.connection.execute("EXPLAIN ANALYZE #{sql}")
    explanation = explained.to_a.map { |row| row['QUERY PLAN'] }.join("\n")

    Rails.logger.info "QUERY ANALYSIS:\n#{explanation}"

    {
      sql: sql,
      explanation: explanation,
      uses_index: explanation.include?('Index Scan') || explanation.include?('Index Only Scan'),
      has_seq_scan: explanation.include?('Seq Scan')
    }
  end

  # Count queries executed in a block
  def count_queries(&block)
    query_count = 0

    subscription = ActiveSupport::Notifications.subscribe('sql.active_record') do |name, start, finish, id, payload|
      # Skip schema queries and transactions
      unless payload[:sql].match?(/^(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE|SET|SELECT [\d\w\s,]+ FROM "schema_migrations")/i)
        query_count += 1
      end
    end

    result = yield
    ActiveSupport::Notifications.unsubscribe(subscription)

    {
      result: result,
      query_count: query_count
    }
  end

  # Benchmark database operations with memory tracking
  def benchmark_with_memory(description, &block)
    start_memory = current_memory_usage
    start_time = Time.current

    result = yield

    end_time = Time.current
    end_memory = current_memory_usage

    duration = ((end_time - start_time) * 1000).round(2)
    memory_delta = end_memory - start_memory

    Rails.logger.info "BENCHMARK [#{description}]: #{duration}ms, Memory: #{memory_delta}KB"

    {
      result: result,
      duration_ms: duration,
      memory_delta_kb: memory_delta,
      description: description
    }
  end

  # Benchmark a query with both timing and query analysis
  def benchmark_and_analyze(description, query, &block)
    # First run to warm up
    block.call if block_given?

    # Benchmarked run
    benchmark_result = benchmark_query(description, &block)

    # Query analysis
    analysis_result = analyze_query(query)

    {
      benchmark: benchmark_result,
      analysis: analysis_result,
      performance_score: calculate_performance_score(benchmark_result, analysis_result)
    }
  end

  # Create large test dataset for performance testing
  def create_performance_dataset(users_count: 100, sleep_records_per_user: 50, follows_per_user: 20)
    Rails.logger.info "Creating performance dataset: #{users_count} users, #{sleep_records_per_user} sleep records per user, #{follows_per_user} follows per user"

    start_time = Time.current

    # Create users
    users = []
    users_count.times do |i|
      users << User.create!(name: "PerfTestUser#{i + 1}")
    end

    # Create sleep records for each user
    users.each do |user|
      sleep_records_per_user.times do |i|
        bedtime = (sleep_records_per_user - i).days.ago + rand(0..23).hours
        wake_time = bedtime + (6 + rand(6)).hours
        duration = ((wake_time - bedtime) / 60).round

        SleepRecord.create!(
          user: user,
          bedtime: bedtime,
          wake_time: wake_time,
          duration_minutes: duration
        )
      end
    end

    # Create follow relationships
    users.each do |user|
      other_users = (users - [user]).sample([follows_per_user, users.length - 1].min)
      other_users.each do |other_user|
        begin
          Follow.create!(user: user, following_user: other_user)
        rescue ActiveRecord::RecordInvalid
          # Skip duplicate follows
        end
      end
    end

    end_time = Time.current
    duration = ((end_time - start_time) * 1000).round(2)

    Rails.logger.info "Performance dataset created in #{duration}ms"

    {
      users_created: users.count,
      sleep_records_created: SleepRecord.where(user: users).count,
      follows_created: Follow.where(user: users).count,
      creation_time_ms: duration
    }
  end

  # Clean up performance test data
  def cleanup_performance_dataset
    Rails.logger.info "Cleaning up performance test data"

    Follow.where(user: User.where("name LIKE 'PerfTestUser%'")).delete_all
    SleepRecord.where(user: User.where("name LIKE 'PerfTestUser%'")).delete_all
    User.where("name LIKE 'PerfTestUser%'").delete_all

    Rails.logger.info "Performance test data cleaned up"
  end

  # Test index effectiveness for common query patterns
  def test_index_effectiveness
    results = {}

    # Test 1: User sleep records by bedtime
    query = SleepRecord.where(user_id: 1).order(bedtime: :desc).limit(20)
    results[:user_sleep_records] = analyze_query(query)

    # Test 2: Social feed query
    query = SleepRecord.joins(:user)
                      .joins("JOIN follows ON follows.following_user_id = sleep_records.user_id")
                      .where(follows: { user_id: 1 })
                      .where.not(wake_time: nil)
                      .where(bedtime: 7.days.ago..Time.current)
                      .order(duration_minutes: :desc)
    results[:social_feed] = analyze_query(query)

    # Test 3: Following list with ordering
    query = Follow.where(user_id: 1).includes(:following_user).order(created_at: :desc)
    results[:following_list] = analyze_query(query)

    # Test 4: Followers list with ordering
    query = Follow.where(following_user_id: 1).includes(:user).order(created_at: :desc)
    results[:followers_list] = analyze_query(query)

    # Test 5: Active sleep session lookup
    query = SleepRecord.where(user_id: 1, wake_time: nil).order(bedtime: :desc).limit(1)
    results[:active_session] = analyze_query(query)

    results
  end

  # Helper to detect N+1 queries
  def detect_n_plus_one(collection_size, &block)
    result = count_queries(&block)

    if result[:query_count] > collection_size + 5 # Allow some base queries
      Rails.logger.warn "POTENTIAL N+1 DETECTED: #{result[:query_count]} queries for #{collection_size} records"
    end

    result[:result]
  end

  # Optimized pagination helper that minimizes queries
  def optimized_paginate(relation, limit:, offset:)
    # Use a single query to get both data and count efficiently
    total_count = relation.count
    records = relation.limit(limit).offset(offset).to_a

    {
      records: records,
      total_count: total_count,
      has_more: (offset + limit) < total_count,
      limit: limit,
      offset: offset
    }
  end

  # Batch loading helper to prevent N+1
  def batch_load(records, association_name)
    ActiveRecord::Associations::Preloader.new.preload(records, association_name)
    records
  end

  # Optimized serialization helper
  def serialize_collection(records, serializer_method = :to_h)
    if records.respond_to?(:map)
      records.map(&serializer_method)
    else
      records.send(serializer_method)
    end
  end

  private

  def current_memory_usage
    `ps -o pid,rss -p #{Process.pid}`.strip.split.last.to_i
  rescue
    0
  end

  def calculate_performance_score(benchmark_result, analysis_result)
    score = 100

    # Deduct points for slow queries
    score -= 20 if benchmark_result[:duration_ms] > 100
    score -= 40 if benchmark_result[:duration_ms] > 500

    # Deduct points for sequential scans
    score -= 30 if analysis_result[:has_seq_scan]

    # Add points for index usage
    score += 10 if analysis_result[:uses_index]

    [score, 0].max
  end
end