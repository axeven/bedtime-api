require 'rails_helper'
require 'performance_helper'

RSpec.describe 'Index Effectiveness', type: :model do
  include FactoryBot::Syntax::Methods

  before(:all) do
    # Create minimal test data for index testing
    @test_user = create(:user, name: 'IndexTestUser')
    @other_user = create(:user, name: 'OtherIndexTestUser')

    # Create some sleep records
    5.times do |i|
      create(:sleep_record, :completed,
             user: @test_user,
             bedtime: (i + 1).days.ago,
             wake_time: (i + 1).days.ago + 8.hours)
    end

    # Create an active session
    create(:sleep_record, user: @test_user, bedtime: 1.hour.ago, wake_time: nil)

    # Create follows
    create(:follow, user: @test_user, following_user: @other_user)
    create(:follow, user: @other_user, following_user: @test_user)
  end

  after(:all) do
    # Clean up test data
    Follow.where(user: [@test_user, @other_user]).delete_all
    SleepRecord.where(user: [@test_user, @other_user]).delete_all
    [@test_user, @other_user].each(&:destroy)
  end

  describe 'Sleep Records Index Usage' do
    it 'uses index for user sleep records lookup' do
      query = SleepRecord.where(user_id: @test_user.id).order(bedtime: :desc)
      analysis = PerformanceHelper.analyze_query(query)

      expect(analysis[:uses_index]).to be true
      expect(analysis[:has_seq_scan]).to be false
    end

    it 'uses index for active sleep session lookup' do
      query = SleepRecord.where(user_id: @test_user.id, wake_time: nil)
      analysis = PerformanceHelper.analyze_query(query)

      expect(analysis[:uses_index]).to be true
      expect(analysis[:explanation]).to include('idx_sleep_records_active')
    end

    it 'uses index for completed sleep records with wake_time filter' do
      query = SleepRecord.where(user_id: @test_user.id).where.not(wake_time: nil)
      analysis = PerformanceHelper.analyze_query(query)

      expect(analysis[:uses_index]).to be true
      # Should use the conditional index for completed records
    end

    it 'uses index for date range queries' do
      query = SleepRecord.where(bedtime: 7.days.ago..Time.current)
                        .where.not(wake_time: nil)
                        .order(bedtime: :desc)
      analysis = PerformanceHelper.analyze_query(query)

      expect(analysis[:uses_index]).to be true
      expect(analysis[:has_seq_scan]).to be false
    end

    it 'uses index for duration-based sorting' do
      query = SleepRecord.where(user_id: @test_user.id)
                        .where.not(wake_time: nil)
                        .order(duration_minutes: :desc)
      analysis = PerformanceHelper.analyze_query(query)

      expect(analysis[:uses_index]).to be true
    end
  end

  describe 'Follows Index Usage' do
    it 'uses index for following list retrieval' do
      query = Follow.where(user_id: @test_user.id).order(created_at: :desc)
      analysis = PerformanceHelper.analyze_query(query)

      expect(analysis[:uses_index]).to be true
      expect(analysis[:explanation]).to include('idx_follows_user_created')
    end

    it 'uses index for followers list retrieval' do
      query = Follow.where(following_user_id: @test_user.id).order(created_at: :desc)
      analysis = PerformanceHelper.analyze_query(query)

      expect(analysis[:uses_index]).to be true
      expect(analysis[:explanation]).to include('idx_follows_following_created')
    end

    it 'uses unique index for follow relationship lookup' do
      query = Follow.where(user_id: @test_user.id, following_user_id: @other_user.id)
      analysis = PerformanceHelper.analyze_query(query)

      expect(analysis[:uses_index]).to be true
      expect(analysis[:explanation]).to include('index_follows_on_user_id_and_following_user_id')
    end
  end

  describe 'Users Index Usage' do
    it 'uses index for user name lookup' do
      query = User.where(name: @test_user.name)
      analysis = PerformanceHelper.analyze_query(query)

      expect(analysis[:uses_index]).to be true
      expect(analysis[:explanation]).to include('idx_users_name')
    end

    it 'uses primary key index for user ID lookup' do
      query = User.where(id: @test_user.id)
      analysis = PerformanceHelper.analyze_query(query)

      expect(analysis[:uses_index]).to be true
      expect(analysis[:explanation]).to include('pkey')
    end
  end

  describe 'Complex Social Query Index Usage' do
    it 'uses index for social feed base query' do
      followed_user_ids = @test_user.following_users.pluck(:id)
      skip 'No followed users for this test user' if followed_user_ids.empty?

      query = SleepRecord.where(user_id: followed_user_ids)
                        .where.not(wake_time: nil)
                        .where(bedtime: 7.days.ago..Time.current)
      analysis = PerformanceHelper.analyze_query(query)

      expect(analysis[:uses_index]).to be true
      expect(analysis[:has_seq_scan]).to be false
    end

    it 'uses index for social feed with duration sorting' do
      followed_user_ids = @test_user.following_users.pluck(:id)
      skip 'No followed users for this test user' if followed_user_ids.empty?

      query = SleepRecord.where(user_id: followed_user_ids)
                        .where.not(wake_time: nil)
                        .order(duration_minutes: :desc)
      analysis = PerformanceHelper.analyze_query(query)

      expect(analysis[:uses_index]).to be true
      # Should use the composite social query index
      expect(analysis[:explanation]).to include('idx_sleep_records_social_query')
    end

    it 'uses index for joins between sleep_records and follows' do
      query = SleepRecord.joins("JOIN follows ON follows.following_user_id = sleep_records.user_id")
                        .where(follows: { user_id: @test_user.id })
                        .where.not(wake_time: nil)
      analysis = PerformanceHelper.analyze_query(query)

      expect(analysis[:uses_index]).to be true
      expect(analysis[:has_seq_scan]).to be false
    end
  end

  describe 'Performance Regression Detection' do
    it 'maintains fast query performance for indexed operations' do
      benchmark_and_analysis = PerformanceHelper.benchmark_and_analyze(
        'User sleep records with index',
        SleepRecord.where(user_id: @test_user.id).order(bedtime: :desc)
      ) do
        SleepRecord.where(user_id: @test_user.id).order(bedtime: :desc).limit(10).to_a
      end

      expect(benchmark_and_analysis[:benchmark][:duration_ms]).to be < 50
      expect(benchmark_and_analysis[:analysis][:uses_index]).to be true
      expect(benchmark_and_analysis[:performance_score]).to be >= 80
    end

    it 'detects performance issues in social queries' do
      benchmark_and_analysis = PerformanceHelper.benchmark_and_analyze(
        'Social feed query with indexes',
        SleepRecord.social_feed_for_user(@test_user).recent_records(7)
      ) do
        SleepRecord.social_feed_for_user(@test_user).recent_records(7).limit(10).to_a
      end

      expect(benchmark_and_analysis[:performance_score]).to be >= 60 # Complex query, lower threshold
    end
  end

  describe 'Index Coverage Analysis' do
    it 'tests all major query patterns for index usage' do
      index_test_results = PerformanceHelper.test_index_effectiveness

      # All major query patterns should use indexes
      expect(index_test_results[:user_sleep_records][:uses_index]).to be true
      expect(index_test_results[:following_list][:uses_index]).to be true
      expect(index_test_results[:followers_list][:uses_index]).to be true
      expect(index_test_results[:active_session][:uses_index]).to be true

      # No query should result in sequential scans
      index_test_results.each do |query_type, result|
        expect(result[:has_seq_scan]).to be false, "Sequential scan detected in #{query_type} query"
      end
    end
  end

  describe 'Database Statistics' do
    it 'provides insights into index usage statistics' do
      # Run some queries to generate statistics
      @test_user.sleep_records.recent_first.limit(5).to_a
      @test_user.follows.includes(:following_user).limit(5).to_a

      # Check that indexes are being utilized
      # Note: This is a basic test - in production you might query pg_stat_user_indexes
      stats_query = "SELECT schemaname, tablename, indexname, idx_tup_read, idx_tup_fetch
                     FROM pg_stat_user_indexes
                     WHERE indexname LIKE 'idx_%'
                     ORDER BY idx_tup_read DESC"

      result = ActiveRecord::Base.connection.execute(stats_query)
      expect(result.count).to be > 0
    end
  end
end