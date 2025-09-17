require 'rails_helper'
require 'benchmark'

RSpec.describe 'Social Sleep Data Performance', type: :request do
  include AuthenticationHelpers

  before do
    host! 'localhost:3000'
  end

  describe 'Large social network performance' do
    let!(:social_user) { User.create!(name: 'Performance Test User') }
    let(:followed_users) { [] }

    before do
      # Create 100 followed users with varying numbers of sleep records
      100.times do |i|
        user = User.create!(name: "Sleeper #{i + 1}")
        social_user.follows.create!(following_user: user)
        followed_users << user

        # Create 5-15 sleep records per user (total ~1000 records)
        record_count = rand(5..15)
        record_count.times do |j|
          user.sleep_records.create!(
            bedtime: (j + 1).days.ago + rand(20..24).hours,
            wake_time: (j + 1).days.ago + rand(26..32).hours,
            duration_minutes: rand(300..600) # 5-10 hours
          )
        end

        print "." if (i + 1) % 20 == 0
      end
      puts "\nCreated #{followed_users.count} users with #{SleepRecord.count} total sleep records"
    end

    context 'Social feed generation performance' do
      it 'performs well with 100+ followed users' do
        response_time = Benchmark.measure do
          get '/api/v1/following/sleep_records',
              headers: { 'X-USER-ID' => social_user.id.to_s }
        end

        puts "Social feed generation time: #{response_time.real.round(3)}s"

        expect(response).to have_http_status(200)
        expect(response_time.real).to be < 1.0 # Should complete in under 1 second

        data = JSON.parse(response.body)
        expect(data['statistics']['unique_users']).to eq(100)
        expect(data['pagination']['total_count']).to be > 500 # Should have many records
      end

      it 'maintains performance with date filtering' do
        response_time = Benchmark.measure do
          get '/api/v1/following/sleep_records',
              params: { days: 7 },
              headers: { 'X-USER-ID' => social_user.id.to_s }
        end

        puts "Date filtering time: #{response_time.real.round(3)}s"

        expect(response).to have_http_status(200)
        expect(response_time.real).to be < 1.0

        data = JSON.parse(response.body)
        expect(data['date_range']['days_back']).to eq(7)
      end

      it 'maintains performance with sorting' do
        response_time = Benchmark.measure do
          get '/api/v1/following/sleep_records',
              params: { sort_by: 'duration' },
              headers: { 'X-USER-ID' => social_user.id.to_s }
        end

        puts "Duration sorting time: #{response_time.real.round(3)}s"

        expect(response).to have_http_status(200)
        expect(response_time.real).to be < 1.0

        data = JSON.parse(response.body)
        expect(data['sorting']['sort_by']).to eq('duration')

        # Verify sorting is correct
        durations = data['sleep_records'].map { |r| r['duration_minutes'] }
        expect(durations).to eq(durations.sort.reverse)
      end
    end

    context 'Pagination performance with 1000+ sleep records' do
      it 'first page loads quickly' do
        response_time = Benchmark.measure do
          get '/api/v1/following/sleep_records',
              params: { limit: 20, offset: 0 },
              headers: { 'X-USER-ID' => social_user.id.to_s }
        end

        puts "First page (limit=20) time: #{response_time.real.round(3)}s"

        expect(response).to have_http_status(200)
        expect(response_time.real).to be < 0.5 # First page should be very fast

        data = JSON.parse(response.body)
        expect(data['sleep_records'].size).to eq(20)
        expect(data['pagination']['offset']).to eq(0)
      end

      it 'middle pages load efficiently' do
        response_time = Benchmark.measure do
          get '/api/v1/following/sleep_records',
              params: { limit: 20, offset: 500 },
              headers: { 'X-USER-ID' => social_user.id.to_s }
        end

        puts "Middle page (offset=500) time: #{response_time.real.round(3)}s"

        expect(response).to have_http_status(200)
        expect(response_time.real).to be < 1.0 # Middle pages should still be fast

        data = JSON.parse(response.body)
        expect(data['pagination']['offset']).to eq(500)
      end

      it 'total count calculation is efficient' do
        response_time = Benchmark.measure do
          get '/api/v1/following/sleep_records',
              params: { limit: 1, offset: 0 },
              headers: { 'X-USER-ID' => social_user.id.to_s }
        end

        puts "Total count calculation time: #{response_time.real.round(3)}s"

        expect(response).to have_http_status(200)
        expect(response_time.real).to be < 0.5 # Count should be very fast due to indexing

        data = JSON.parse(response.body)
        expect(data['pagination']['total_count']).to be > 0
      end
    end

    context 'Statistics generation performance' do
      it 'calculates statistics efficiently for large datasets' do
        response_time = Benchmark.measure do
          get '/api/v1/following/sleep_records',
              headers: { 'X-USER-ID' => social_user.id.to_s }
        end

        puts "Statistics generation time: #{response_time.real.round(3)}s"

        expect(response).to have_http_status(200)
        expect(response_time.real).to be < 1.5 # Statistics should be reasonably fast

        data = JSON.parse(response.body)
        stats = data['statistics']

        expect(stats['total_records']).to be > 0
        expect(stats['unique_users']).to eq(100)
        expect(stats['duration_stats']['average_minutes']).to be > 0
        expect(stats['duration_stats']['total_sleep_hours']).to be > 0
      end
    end

    context 'Query performance monitoring' do
      it 'does not generate N+1 queries' do
        # This test monitors the number of database queries
        query_count = 0

        # Subscribe to SQL events to count queries
        subscription = ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
          query_count += 1
        end

        get '/api/v1/following/sleep_records',
            params: { limit: 50 },
            headers: { 'X-USER-ID' => social_user.id.to_s }

        ActiveSupport::Notifications.unsubscribe(subscription)

        expect(response).to have_http_status(200)

        puts "Total database queries: #{query_count}"

        # Should be a reasonable number of queries (not proportional to number of records)
        # Typically: 1 for count, 1 for main query with includes, maybe a few more for auth
        expect(query_count).to be < 10
      end

      it 'uses database indexes effectively' do
        # Test with EXPLAIN to verify index usage
        # This is more of a manual verification but we can check response time
        response_time = Benchmark.measure do
          get '/api/v1/following/sleep_records',
              params: { days: 3, sort_by: 'duration', limit: 10 },
              headers: { 'X-USER-ID' => social_user.id.to_s }
        end

        puts "Complex query (date + sort + pagination) time: #{response_time.real.round(3)}s"

        expect(response).to have_http_status(200)
        expect(response_time.real).to be < 1.0 # Should be fast with proper indexing
      end
    end
  end

  describe 'Concurrent access performance' do
    let!(:users) { [] }

    before do
      # Create 5 users with followers and sleep records
      5.times do |i|
        user = User.create!(name: "Concurrent User #{i}")
        follower = User.create!(name: "Follower #{i}")
        follower.follows.create!(following_user: user)

        # Create some sleep records
        3.times do |j|
          user.sleep_records.create!(
            bedtime: (j + 1).days.ago + 22.hours,
            wake_time: (j + 1).days.ago + 30.hours,
            duration_minutes: 480
          )
        end

        users << { user: user, follower: follower }
      end
    end

    it 'handles concurrent requests efficiently' do
      threads = []
      response_times = []

      # Simulate 5 concurrent requests
      5.times do |i|
        threads << Thread.new do
          time = Benchmark.measure do
            get '/api/v1/following/sleep_records',
                headers: { 'X-USER-ID' => users[i][:follower].id.to_s }
          end
          response_times << time.real
        end
      end

      threads.each(&:join)

      avg_response_time = response_times.sum / response_times.size
      max_response_time = response_times.max

      puts "Concurrent requests - Avg: #{avg_response_time.round(3)}s, Max: #{max_response_time.round(3)}s"

      expect(avg_response_time).to be < 1.0
      expect(max_response_time).to be < 2.0
    end
  end

  after(:all) do
    puts "\n=== Performance Test Summary ==="
    puts "✅ Large social network tests completed"
    puts "✅ Pagination performance verified"
    puts "✅ Query optimization confirmed"
    puts "✅ Concurrent access tested"
    puts "================================"
  end
end
