require 'rails_helper'

RSpec.describe 'Query Performance Benchmarks', type: :request do
  include PerformanceHelper

  before(:all) do
    # Create large dataset for performance testing
    @dataset = create_performance_dataset(
      users_count: 50,
      sleep_records_per_user: 100,
      follows_per_user: 10
    )
    @test_user = User.find_by(name: 'PerfTestUser1')
  end

  after(:all) do
    cleanup_performance_dataset
  end

  let(:auth_headers) { { 'X-USER-ID' => @test_user.id.to_s } }

  describe 'Sleep Records Performance' do
    it 'benchmarks sleep history retrieval with large datasets' do
      performance = benchmark_query('Sleep records index with 100 records') do
        get '/api/v1/sleep_records', headers: auth_headers, params: { limit: 50 }
      end

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      # Performance expectations
      expect(performance[:duration_ms]).to be < 200
      expect(json['data']['sleep_records'].length).to be <= 50
      expect(json['data']['pagination']['total_count']).to be > 50

      Rails.logger.info "Sleep records performance: #{performance[:duration_ms]}ms for #{json['data']['sleep_records'].length} records"
    end

    it 'benchmarks filtered sleep record queries' do
      performance = benchmark_query('Filtered sleep records query') do
        get '/api/v1/sleep_records', headers: auth_headers, params: {
          completed: 'true',
          limit: 20
        }
      end

      expect(response).to have_http_status(:ok)
      expect(performance[:duration_ms]).to be < 150
    end

    it 'measures memory usage for sleep record serialization' do
      memory_usage = benchmark_with_memory('Sleep record serialization') do
        get '/api/v1/sleep_records', headers: auth_headers, params: { limit: 100 }
      end

      expect(response).to have_http_status(:ok)
      expect(memory_usage[:memory_delta_kb]).to be < 5000 # 5MB limit
      expect(memory_usage[:duration_ms]).to be < 300
    end
  end

  describe 'Social Following Performance' do
    it 'benchmarks following list retrieval' do
      performance = benchmark_query('Following list with includes') do
        get '/api/v1/follows', headers: auth_headers, params: { limit: 20 }
      end

      expect(response).to have_http_status(:ok)
      expect(performance[:duration_ms]).to be < 100
    end

    it 'benchmarks followers list retrieval' do
      performance = benchmark_query('Followers list with includes') do
        get '/api/v1/followers', headers: auth_headers, params: { limit: 20 }
      end

      expect(response).to have_http_status(:ok)
      expect(performance[:duration_ms]).to be < 100
    end

    it 'verifies following/followers count caching performance' do
      # First call (cache miss)
      miss_performance = benchmark_query('Followers count cache miss') do
        @test_user.followers_count
      end

      # Second call (cache hit)
      hit_performance = benchmark_query('Followers count cache hit') do
        @test_user.followers_count
      end

      # Cache hit should be significantly faster
      expect(hit_performance[:duration_ms]).to be < (miss_performance[:duration_ms] * 0.5)
    end
  end

  describe 'Social Sleep Data Performance' do
    it 'benchmarks social sleep feed with complex aggregations' do
      performance = benchmark_query('Social sleep feed with statistics') do
        get '/api/v1/following/sleep_records', headers: auth_headers, params: {
          days: 7,
          limit: 30,
          sort_by: 'duration'
        }
      end

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(performance[:duration_ms]).to be < 400
      expect(json['data']['sleep_records']).to be_present
      expect(json['data']['statistics']).to be_present

      Rails.logger.info "Social feed performance: #{performance[:duration_ms]}ms for #{json['data']['sleep_records'].length} records"
    end

    it 'benchmarks different sorting options' do
      sort_options = [ 'duration', 'bedtime', 'wake_time', 'created_at' ]
      results = {}

      sort_options.each do |sort_option|
        performance = benchmark_query("Social feed sorted by #{sort_option}") do
          get '/api/v1/following/sleep_records', headers: auth_headers, params: {
            days: 7,
            sort_by: sort_option,
            limit: 20
          }
        end

        expect(response).to have_http_status(:ok)
        results[sort_option] = performance[:duration_ms]
        expect(performance[:duration_ms]).to be < 300
      end

      Rails.logger.info "Sorting performance: #{results}"
    end

    it 'measures social statistics calculation performance' do
      # Test with different day ranges
      [ 3, 7, 14, 30 ].each do |days|
        performance = benchmark_query("Statistics for #{days} days") do
          get '/api/v1/following/sleep_records', headers: auth_headers, params: {
            days: days,
            limit: 5 # Small limit to focus on statistics performance
          }
        end

        expect(response).to have_http_status(:ok)
        # Statistics shouldn't significantly impact performance
        expect(performance[:duration_ms]).to be < 500
      end
    end
  end

  describe 'Database Query Analysis' do
    it 'analyzes and benchmarks critical query patterns' do
      skip 'Requires development environment' unless Rails.env.development?

      # Test user sleep records query
      query = @test_user.sleep_records.recent_first.limit(20)
      result = benchmark_and_analyze('User sleep records query', query) do
        query.to_a
      end

      expect(result[:analysis][:uses_index]).to be true
      expect(result[:benchmark][:duration_ms]).to be < 100
      expect(result[:performance_score]).to be > 70

      # Test social feed query
      social_query = SleepRecord.social_feed_for_user(@test_user).limit(20)
      social_result = benchmark_and_analyze('Social feed query', social_query) do
        social_query.to_a
      end

      expect(social_result[:analysis][:uses_index]).to be true
      expect(social_result[:benchmark][:duration_ms]).to be < 200
      expect(social_result[:performance_score]).to be > 60
    end

    it 'verifies index effectiveness for common queries' do
      skip 'Requires development environment' unless Rails.env.development?

      results = test_index_effectiveness

      # All critical queries should use indexes
      results.each do |query_name, analysis|
        expect(analysis[:uses_index]).to be true, "#{query_name} should use indexes"
        Rails.logger.info "#{query_name}: uses_index=#{analysis[:uses_index]}, has_seq_scan=#{analysis[:has_seq_scan]}"
      end
    end
  end

  describe 'Concurrent Performance' do
    it 'handles concurrent requests efficiently' do
      threads = []
      results = []
      thread_count = 5

      thread_count.times do |i|
        threads << Thread.new do
          performance = benchmark_query("Concurrent request #{i}") do
            get '/api/v1/sleep_records', headers: auth_headers, params: { limit: 20 }
          end
          results << performance[:duration_ms]
        end
      end

      threads.each(&:join)

      # All requests should complete in reasonable time
      results.each do |duration|
        expect(duration).to be < 300
      end

      average_duration = results.sum / results.length.to_f
      Rails.logger.info "Concurrent performance - Average: #{average_duration.round(2)}ms, Max: #{results.max}ms"
    end
  end

  describe 'Performance Regression Detection' do
    it 'maintains baseline performance metrics' do
      baseline_metrics = {
        sleep_records_index: 200,      # ms
        social_feed: 400,              # ms
        following_list: 100,           # ms
        followers_list: 100            # ms
      }

      # Test each endpoint against baseline
      actual_metrics = {}

      # Sleep records
      perf = benchmark_query('Sleep records baseline') do
        get '/api/v1/sleep_records', headers: auth_headers, params: { limit: 20 }
      end
      actual_metrics[:sleep_records_index] = perf[:duration_ms]

      # Social feed
      perf = benchmark_query('Social feed baseline') do
        get '/api/v1/following/sleep_records', headers: auth_headers, params: { days: 7, limit: 20 }
      end
      actual_metrics[:social_feed] = perf[:duration_ms]

      # Following list
      perf = benchmark_query('Following list baseline') do
        get '/api/v1/follows', headers: auth_headers, params: { limit: 20 }
      end
      actual_metrics[:following_list] = perf[:duration_ms]

      # Followers list
      perf = benchmark_query('Followers list baseline') do
        get '/api/v1/followers', headers: auth_headers, params: { limit: 20 }
      end
      actual_metrics[:followers_list] = perf[:duration_ms]

      # Verify all endpoints meet baseline performance
      baseline_metrics.each do |endpoint, baseline|
        actual = actual_metrics[endpoint]
        expect(actual).to be < baseline, "#{endpoint} took #{actual}ms, baseline is #{baseline}ms"
      end

      Rails.logger.info "Performance baseline check passed: #{actual_metrics}"
    end

    it 'detects query count regressions' do
      endpoints = [
        { path: '/api/v1/sleep_records', params: { limit: 20 }, max_queries: 3 },
        { path: '/api/v1/follows', params: { limit: 20 }, max_queries: 3 },
        { path: '/api/v1/followers', params: { limit: 20 }, max_queries: 3 },
        { path: '/api/v1/following/sleep_records', params: { days: 7, limit: 20 }, max_queries: 5 }
      ]

      endpoints.each do |endpoint_config|
        result = count_queries do
          get endpoint_config[:path], headers: auth_headers, params: endpoint_config[:params]
        end

        expect(response).to have_http_status(:ok)
        expect(result[:query_count]).to be <= endpoint_config[:max_queries],
          "#{endpoint_config[:path]} executed #{result[:query_count]} queries, limit is #{endpoint_config[:max_queries]}"
      end
    end
  end
end
