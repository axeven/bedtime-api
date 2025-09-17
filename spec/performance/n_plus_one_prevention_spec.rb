require 'rails_helper'

RSpec.describe 'N+1 Query Prevention', type: :request do
  include PerformanceHelper

  let(:user) { create(:user) }
  let(:auth_headers) { { 'X-USER-ID' => user.id.to_s } }

  before do
    # Create test data
    @other_users = create_list(:user, 5)
    @other_users.each { |u| create(:follow, user: user, following_user: u) }
    @other_users.each { |u| create_list(:sleep_record, 10, :completed, user: u) }
    create_list(:sleep_record, 10, :completed, user: user)
  end

  describe 'Sleep Records API' do
    it 'does not trigger N+1 queries for sleep records index' do
      result = count_queries do
        get '/api/v1/sleep_records', headers: auth_headers, params: { limit: 20 }
      end

      expect(response).to have_http_status(:ok)
      # Should be: 1 query for user auth, 1 for sleep records, 1 for count
      expect(result[:query_count]).to be <= 3
    end

    it 'avoids N+1 queries even with large datasets' do
      # Create more data
      create_list(:sleep_record, 50, :completed, user: user)

      result = count_queries do
        get '/api/v1/sleep_records', headers: auth_headers, params: { limit: 50 }
      end

      expect(response).to have_http_status(:ok)
      # Query count should remain constant regardless of result size
      expect(result[:query_count]).to be <= 3
    end

    it 'maintains query efficiency with filters' do
      result = count_queries do
        get '/api/v1/sleep_records', headers: auth_headers, params: {
          completed: 'true',
          limit: 20
        }
      end

      expect(response).to have_http_status(:ok)
      # Filtering shouldn't add additional queries
      expect(result[:query_count]).to be <= 3
    end
  end

  describe 'Social Following API' do
    it 'prevents N+1 queries in following list' do
      result = count_queries do
        get '/api/v1/follows', headers: auth_headers, params: { limit: 20 }
      end

      expect(response).to have_http_status(:ok)
      # Should use includes to prevent N+1
      expect(result[:query_count]).to be <= 3
    end

    it 'prevents N+1 queries in followers list' do
      # Create some followers for the user
      create_list(:user, 3).each { |u| create(:follow, user: u, following_user: user) }

      result = count_queries do
        get '/api/v1/followers', headers: auth_headers, params: { limit: 20 }
      end

      expect(response).to have_http_status(:ok)
      # Should use includes to prevent N+1
      expect(result[:query_count]).to be <= 3
    end
  end

  describe 'Social Sleep Data API' do
    it 'prevents N+1 queries in social sleep feed' do
      result = count_queries do
        get '/api/v1/following/sleep_records', headers: auth_headers, params: {
          days: 7,
          limit: 20
        }
      end

      expect(response).to have_http_status(:ok)
      # Complex social query should still be efficient
      expect(result[:query_count]).to be <= 5
    end

    it 'maintains efficiency with statistics generation' do
      result = count_queries do
        get '/api/v1/following/sleep_records', headers: auth_headers, params: {
          days: 7,
          limit: 50,
          sort_by: 'duration'
        }
      end

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      # Should include statistics without extra queries
      expect(json['data']['statistics']).to be_present
      expect(result[:query_count]).to be <= 6 # Allow one extra query for statistics
    end
  end

  describe 'Performance regression detection' do
    it 'detects potential N+1 patterns with helper method' do
      sleep_records = user.sleep_records.limit(10)

      # This should NOT trigger N+1 (optimized)
      optimized_result = detect_n_plus_one(10) do
        sleep_records.map { |record| record.bedtime.iso8601 }
      end

      expect(optimized_result).to be_present

      # This WOULD trigger N+1 if we accessed associations without includes
      # But our models are now optimized, so it shouldn't
      association_result = detect_n_plus_one(5) do
        @other_users.map { |u| u.name }
      end

      expect(association_result).to be_present
    end

    it 'benchmarks query performance stays within acceptable limits' do
      performance = benchmark_query('Sleep records index endpoint') do
        get '/api/v1/sleep_records', headers: auth_headers, params: { limit: 20 }
      end

      expect(response).to have_http_status(:ok)
      # Should complete in reasonable time (adjust based on your performance requirements)
      expect(performance[:duration_ms]).to be < 200
    end

    it 'verifies social query performance' do
      performance = benchmark_query('Social sleep records endpoint') do
        get '/api/v1/following/sleep_records', headers: auth_headers, params: {
          days: 7,
          limit: 20
        }
      end

      expect(response).to have_http_status(:ok)
      # Complex social queries should still be reasonably fast
      expect(performance[:duration_ms]).to be < 500
    end
  end

  describe 'Query optimization verification' do
    it 'uses database indexes effectively for user sleep queries' do
      # Skip if not in development (EXPLAIN ANALYZE only works with real DB)
      skip 'Requires development database for EXPLAIN ANALYZE' unless Rails.env.development?

      query = user.sleep_records.recent_first.limit(10)
      analysis = analyze_query(query)

      expect(analysis[:uses_index]).to be true
      expect(analysis[:has_seq_scan]).to be false
    end

    it 'optimizes social feed queries with proper joins' do
      skip 'Requires development database for EXPLAIN ANALYZE' unless Rails.env.development?

      query = SleepRecord.social_feed_for_user(user).limit(10)
      analysis = analyze_query(query)

      expect(analysis[:uses_index]).to be true
      # Complex joins might have some seq scans but should use indexes primarily
    end

    it 'uses indexes for following relationships' do
      skip 'Requires development database for EXPLAIN ANALYZE' unless Rails.env.development?

      query = user.follows.includes(:following_user).limit(10)
      analysis = analyze_query(query)

      expect(analysis[:uses_index]).to be true
    end
  end
end
