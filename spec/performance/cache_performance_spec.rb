require 'rails_helper'
require 'benchmark'

RSpec.describe 'Cache Performance', type: :request do
  let!(:users) { create_list(:user, 10) }
  let!(:test_user) { users.first }
  let(:headers) { { 'X-USER-ID' => test_user.id.to_s, 'Content-Type' => 'application/json' } }

  before(:all) do
    # Create test data for performance testing
    @performance_users = create_list(:user, 20)
    @test_user = @performance_users.first

    # Create follows for realistic testing
    @performance_users[1..10].each do |user|
      create(:follow, user: @test_user, following_user: user)
      create(:follow, user: user, following_user: @test_user)
    end

    # Create sleep records for social sleep data
    @performance_users.each do |user|
      create_list(:sleep_record, 5, :completed, user: user)
    end
  end

  after(:all) do
    User.where(id: @performance_users.pluck(:id)).destroy_all
  end

  before(:each) do
    Rails.cache.clear
  end

  describe 'Cache vs No-Cache Performance' do
    let(:performance_headers) { { 'X-USER-ID' => @test_user.id.to_s } }

    it 'shows significant improvement with caching for following lists' do
      # Measure without cache (first request)
      no_cache_time = Benchmark.measure do
        10.times do
          Rails.cache.clear
          get '/api/v1/follows', headers: performance_headers
          expect(response).to have_http_status(:ok)
        end
      end

      # Warm cache
      get '/api/v1/follows', headers: performance_headers

      # Measure with cache (subsequent requests)
      with_cache_time = Benchmark.measure do
        10.times do
          get '/api/v1/follows', headers: performance_headers
          expect(response).to have_http_status(:ok)
        end
      end

      puts "\nCache Performance Results:"
      puts "Without Cache: #{no_cache_time.real.round(3)}s"
      puts "With Cache: #{with_cache_time.real.round(3)}s"
      puts "Improvement: #{(no_cache_time.real / with_cache_time.real).round(2)}x faster"

      # Cache should be at least 2x faster
      expect(no_cache_time.real / with_cache_time.real).to be > 2.0
    end

    it 'shows improvement for social sleep data with caching' do
      # Measure without cache (first request)
      no_cache_time = Benchmark.measure do
        5.times do
          Rails.cache.clear
          get '/api/v1/following/sleep_records', headers: performance_headers
          expect(response).to have_http_status(:ok)
        end
      end

      # Warm cache
      get '/api/v1/following/sleep_records', headers: performance_headers

      # Measure with cache (subsequent requests)
      with_cache_time = Benchmark.measure do
        5.times do
          get '/api/v1/following/sleep_records', headers: performance_headers
          expect(response).to have_http_status(:ok)
        end
      end

      puts "\nSocial Sleep Data Cache Performance:"
      puts "Without Cache: #{no_cache_time.real.round(3)}s"
      puts "With Cache: #{with_cache_time.real.round(3)}s"
      puts "Improvement: #{(no_cache_time.real / with_cache_time.real).round(2)}x faster"

      # Cache should provide some improvement
      expect(no_cache_time.real / with_cache_time.real).to be > 1.5
    end
  end

  describe 'Cache Operation Performance' do
    it 'benchmarks individual cache operations' do
      key_prefix = 'performance_test'

      # Test write performance
      write_time = Benchmark.measure do
        100.times do |i|
          key = CacheService.cache_key(key_prefix, @test_user.id, i)
          CacheService.fetch(key, expires_in: 1.hour) { { data: "test_#{i}" } }
        end
      end

      # Test read performance
      read_time = Benchmark.measure do
        100.times do |i|
          key = CacheService.cache_key(key_prefix, @test_user.id, i)
          Rails.cache.read(key)
        end
      end

      # Test pattern delete performance
      delete_time = Benchmark.measure do
        CacheService.delete_pattern("#{key_prefix}:user:#{@test_user.id}:*")
      end

      puts "\nIndividual Cache Operation Performance:"
      puts "Write (100 ops): #{write_time.real.round(3)}s (#{(100 / write_time.real).round(0)} ops/sec)"
      puts "Read (100 ops): #{read_time.real.round(3)}s (#{(100 / read_time.real).round(0)} ops/sec)"
      puts "Pattern Delete (100 keys): #{delete_time.real.round(3)}s"

      # Performance expectations
      expect(write_time.real).to be < 1.0  # Should write 100 items in less than 1 second
      expect(read_time.real).to be < 0.5   # Should read 100 items in less than 0.5 seconds
      expect(delete_time.real).to be < 0.1 # Should delete pattern in less than 0.1 seconds
    end

    it 'benchmarks cache warming performance' do
      cache_warm_time = Benchmark.measure do
        10.times do |i|
          user = @performance_users[i]
          CacheService.warm_user_cache(user)
        end
      end

      puts "\nCache Warming Performance:"
      puts "Warm 10 users: #{cache_warm_time.real.round(3)}s (#{(10 / cache_warm_time.real).round(2)} users/sec)"

      # Should be able to warm cache for multiple users quickly
      expect(cache_warm_time.real).to be < 2.0
    end
  end

  describe 'Memory Usage with Caching' do
    it 'monitors memory usage with large cached datasets' do
      # Get initial cache stats
      initial_stats = CacheService.cache_stats

      # Cache data for multiple users
      @performance_users.each do |user|
        user_headers = { 'X-USER-ID' => user.id.to_s }
        get '/api/v1/follows', headers: user_headers
        get '/api/v1/followers', headers: user_headers
        get '/api/v1/following/sleep_records', headers: user_headers
      end

      # Get final cache stats
      final_stats = CacheService.cache_stats

      puts "\nMemory Usage:"
      puts "Initial memory: #{initial_stats[:used_memory]}"
      puts "Final memory: #{final_stats[:used_memory]}"
      puts "Cache hit rate: #{final_stats[:hit_rate]}%"

      # Verify cache is being used effectively
      expect(final_stats[:hit_rate]).to be > 0
    end
  end

  describe 'Concurrent Access Performance' do
    it 'handles concurrent cache access efficiently' do
      # This test simulates multiple concurrent requests
      threads = []
      results = []

      concurrent_time = Benchmark.measure do
        5.times do
          threads << Thread.new do
            # Each thread makes multiple requests
            thread_results = []
            user_headers = { 'X-USER-ID' => @test_user.id.to_s }

            3.times do
              get '/api/v1/follows', headers: user_headers
              thread_results << response.status
            end

            results << thread_results
          end
        end

        threads.each(&:join)
      end

      puts "\nConcurrent Access Performance:"
      puts "5 threads × 3 requests: #{concurrent_time.real.round(3)}s"
      puts "Average per request: #{(concurrent_time.real / 15).round(3)}s"

      # All requests should succeed
      results.flatten.each do |status|
        expect(status).to eq(200)
      end

      # Concurrent access should complete reasonably quickly
      expect(concurrent_time.real).to be < 5.0
    end
  end
end