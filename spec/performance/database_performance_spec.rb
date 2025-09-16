require 'rails_helper'
require 'performance_helper'

RSpec.describe 'Database Performance', type: :model do
  include FactoryBot::Syntax::Methods

  before(:all) do
    # Create performance test dataset
    @performance_data = PerformanceHelper.create_performance_dataset(
      users_count: 50,
      sleep_records_per_user: 30,
      follows_per_user: 15
    )
    @test_user = User.where("name LIKE 'PerfTestUser%'").first
  end

  after(:all) do
    # Clean up performance test data
    PerformanceHelper.cleanup_performance_dataset
  end

  describe 'Sleep Records Query Performance' do
    it 'performs well for user sleep records retrieval' do
      benchmark = PerformanceHelper.benchmark_query('User sleep records query') do
        @test_user.sleep_records.recent_first.limit(20).to_a
      end

      expect(benchmark[:duration_ms]).to be < 50 # Should be very fast with proper indexing
    end

    it 'performs well for active sleep session lookup' do
      benchmark = PerformanceHelper.benchmark_query('Active sleep session query') do
        @test_user.sleep_records.active.first
      end

      expect(benchmark[:duration_ms]).to be < 20 # Should be extremely fast
    end

    it 'performs well for completed sleep records filtering' do
      benchmark = PerformanceHelper.benchmark_query('Completed sleep records query') do
        @test_user.sleep_records.completed.order(bedtime: :desc).limit(50).to_a
      end

      expect(benchmark[:duration_ms]).to be < 50
    end

    it 'performs well for sleep records date range filtering' do
      benchmark = PerformanceHelper.benchmark_query('Date range sleep records query') do
        @test_user.sleep_records
                  .where(bedtime: 30.days.ago..Time.current)
                  .order(bedtime: :desc)
                  .limit(30)
                  .to_a
      end

      expect(benchmark[:duration_ms]).to be < 100
    end
  end

  describe 'Social Following Query Performance' do
    it 'performs well for following list retrieval' do
      benchmark = PerformanceHelper.benchmark_query('Following list query') do
        @test_user.follows.includes(:following_user).order(created_at: :desc).limit(20).to_a
      end

      expect(benchmark[:duration_ms]).to be < 100
    end

    it 'performs well for followers list retrieval' do
      benchmark = PerformanceHelper.benchmark_query('Followers list query') do
        @test_user.follower_relationships.includes(:user).order(created_at: :desc).limit(20).to_a
      end

      expect(benchmark[:duration_ms]).to be < 100
    end

    it 'performs well for follow relationship lookup' do
      other_user = User.where("name LIKE 'PerfTestUser%'").where.not(id: @test_user.id).first

      benchmark = PerformanceHelper.benchmark_query('Follow relationship lookup') do
        @test_user.follows.find_by(following_user: other_user)
      end

      expect(benchmark[:duration_ms]).to be < 20
    end
  end

  describe 'Social Sleep Data Query Performance' do
    it 'performs well for social feed query' do
      # This is the most complex query - social sleep records
      benchmark = PerformanceHelper.benchmark_query('Social feed query') do
        SleepRecord.social_feed_for_user(@test_user)
                  .recent_records(7)
                  .apply_sorting('duration')
                  .limit(20)
                  .to_a
      end

      expect(benchmark[:duration_ms]).to be < 200 # More complex query, allowing more time
    end

    it 'performs well for social feed statistics calculation' do
      benchmark = PerformanceHelper.benchmark_query('Social feed statistics') do
        records = SleepRecord.social_feed_for_user(@test_user).recent_records(7)
        {
          count: records.count,
          avg_duration: records.average(:duration_minutes),
          max_duration: records.maximum(:duration_minutes),
          min_duration: records.minimum(:duration_minutes)
        }
      end

      expect(benchmark[:duration_ms]).to be < 150
    end

    it 'performs well for social feed with complex sorting' do
      benchmark = PerformanceHelper.benchmark_query('Social feed with duration sorting') do
        SleepRecord.social_feed_for_user(@test_user)
                  .recent_records(14)
                  .order(duration_minutes: :desc, bedtime: :desc)
                  .limit(30)
                  .to_a
      end

      expect(benchmark[:duration_ms]).to be < 200
    end
  end

  describe 'User Lookup Performance' do
    it 'performs well for user lookup by ID' do
      benchmark = PerformanceHelper.benchmark_query('User lookup by ID') do
        User.find(@test_user.id)
      end

      expect(benchmark[:duration_ms]).to be < 10
    end

    it 'performs well for user lookup by name' do
      benchmark = PerformanceHelper.benchmark_query('User lookup by name') do
        User.find_by(name: @test_user.name)
      end

      expect(benchmark[:duration_ms]).to be < 20 # Should benefit from name index
    end
  end

  describe 'Pagination Performance' do
    it 'performs well for paginated sleep records' do
      benchmark = PerformanceHelper.benchmark_query('Paginated sleep records') do
        @test_user.sleep_records.order(bedtime: :desc).limit(20).offset(10).to_a
      end

      expect(benchmark[:duration_ms]).to be < 50
    end

    it 'performs well for paginated social feed' do
      benchmark = PerformanceHelper.benchmark_query('Paginated social feed') do
        SleepRecord.social_feed_for_user(@test_user)
                  .recent_records(7)
                  .order(duration_minutes: :desc)
                  .limit(20)
                  .offset(20)
                  .to_a
      end

      expect(benchmark[:duration_ms]).to be < 200
    end

    it 'performs well for count queries on large datasets' do
      benchmark = PerformanceHelper.benchmark_query('Count query for social feed') do
        SleepRecord.social_feed_for_user(@test_user).recent_records(30).count
      end

      expect(benchmark[:duration_ms]).to be < 100
    end
  end

  describe 'Query Count Optimization' do
    it 'minimizes queries for sleep records index' do
      query_result = PerformanceHelper.count_queries do
        @test_user.sleep_records.recent_first.limit(10).to_a
      end

      expect(query_result[:query_count]).to be <= 2 # Should be 1 query
    end

    it 'minimizes queries for following list with user data' do
      query_result = PerformanceHelper.count_queries do
        @test_user.follows.includes(:following_user).limit(10).map do |follow|
          { id: follow.following_user.id, name: follow.following_user.name }
        end
      end

      expect(query_result[:query_count]).to be <= 3 # Should be 2 queries max (follows + users)
    end

    it 'minimizes queries for social feed with user names' do
      query_result = PerformanceHelper.count_queries do
        SleepRecord.social_feed_for_user(@test_user).limit(5).map do |record|
          { duration: record.duration_minutes, user_name: record.user_name }
        end
      end

      expect(query_result[:query_count]).to be <= 4 # Should avoid N+1 queries
    end
  end

  describe 'Memory Usage Performance' do
    it 'uses reasonable memory for large result sets' do
      memory_result = PerformanceHelper.benchmark_with_memory('Large sleep records query') do
        @test_user.sleep_records.limit(100).to_a
      end

      expect(memory_result[:memory_delta_kb]).to be < 5000 # Should not use excessive memory
    end

    it 'uses reasonable memory for social feed aggregation' do
      memory_result = PerformanceHelper.benchmark_with_memory('Social feed aggregation') do
        SleepRecord.social_feed_for_user(@test_user).recent_records(30).to_a
      end

      expect(memory_result[:memory_delta_kb]).to be < 10000
    end
  end

  describe 'Concurrent Query Performance' do
    it 'handles concurrent queries efficiently' do
      threads = []
      results = []

      5.times do
        threads << Thread.new do
          benchmark = PerformanceHelper.benchmark_query('Concurrent query') do
            @test_user.sleep_records.recent_first.limit(10).to_a
          end
          results << benchmark[:duration_ms]
        end
      end

      threads.each(&:join)

      # All concurrent queries should complete in reasonable time
      expect(results.max).to be < 100
      expect(results.average).to be < 50
    end
  end
end