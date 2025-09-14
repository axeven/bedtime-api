require 'rails_helper'

RSpec.describe 'API Performance', type: :request do
  describe 'sleep history performance' do
    let!(:user) { create(:user, name: 'Heavy User') }

    before do
      # Create a large number of sleep records to test pagination performance
      100.times do |i|
        create(:sleep_record,
          user: user,
          bedtime: (i * 2 + 2).hours.ago,
          wake_time: (i * 2 + 1).hours.ago
        )
      end
    end

    it 'retrieves sleep history efficiently with large datasets' do
      start_time = Time.current

      get '/api/v1/sleep_records',
        params: { limit: 20, offset: 0 },
        headers: { 'X-USER-ID' => user.id.to_s }

      response_time = Time.current - start_time

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)

      # Should return exactly 20 records
      expect(data['sleep_records'].length).to eq(20)
      expect(data['pagination']['total_count']).to eq(100)
      expect(data['pagination']['has_more']).to be true

      # Response should be reasonably fast (under 1 second for 100 records)
      expect(response_time).to be < 1.0

      # Verify records are properly ordered (most recent first)
      bedtimes = data['sleep_records'].map { |r| Time.parse(r['bedtime']) }
      expect(bedtimes).to eq(bedtimes.sort.reverse)
    end

    it 'handles pagination efficiently across large datasets' do
      pages_tested = 0
      total_records = 0

      # Test multiple pages
      (0..4).each do |page|
        start_time = Time.current

        get '/api/v1/sleep_records',
          params: { limit: 20, offset: page * 20 },
          headers: { 'X-USER-ID' => user.id.to_s }

        response_time = Time.current - start_time

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)

        # Each page should still be fast
        expect(response_time).to be < 1.0

        total_records += data['sleep_records'].length
        pages_tested += 1

        # Verify pagination metadata
        expect(data['pagination']['offset']).to eq(page * 20)
        expect(data['pagination']['limit']).to eq(20)
      end

      expect(pages_tested).to eq(5)
      expect(total_records).to eq(100) # 5 pages * 20 records each
    end

    it 'performs filtering efficiently' do
      start_time = Time.current

      get '/api/v1/sleep_records',
        params: { completed: 'true', limit: 50 },
        headers: { 'X-USER-ID' => user.id.to_s }

      response_time = Time.current - start_time

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)

      # Should return completed records efficiently
      expect(response_time).to be < 1.0
      expect(data['sleep_records'].length).to eq(50)

      # All returned records should be completed
      data['sleep_records'].each do |record|
        expect(record['active']).to be false
        expect(record['wake_time']).to be_present
        expect(record['duration_minutes']).to be_present
      end
    end
  end

  describe 'concurrent operations performance' do
    let!(:users) { create_list(:user, 10) }

    it 'handles multiple concurrent clock-ins efficiently' do
      start_time = Time.current
      threads = []
      results = []

      # 10 different users clock in simultaneously
      users.each_with_index do |user, index|
        threads << Thread.new do
          request_start = Time.current
          post '/api/v1/sleep_records',
            headers: { 'X-USER-ID' => user.id.to_s, 'Content-Type' => 'application/json' }
          request_time = Time.current - request_start

          results << {
            user_id: user.id,
            status: response.status,
            response_time: request_time
          }
        end
      end

      threads.each(&:join)
      total_time = Time.current - start_time

      # All requests should succeed
      successful_requests = results.select { |r| r[:status] == 201 }
      expect(successful_requests.length).to eq(10)

      # Individual requests should be fast
      results.each do |result|
        expect(result[:response_time]).to be < 2.0
      end

      # Total concurrent execution should be reasonable
      expect(total_time).to be < 5.0

      # Verify all users have active sessions
      users.each do |user|
        expect(user.sleep_records.active.count).to eq(1)
      end
    end

    it 'handles mixed operations efficiently' do
      # Create some existing sessions
      users[0..4].each do |user|
        create(:sleep_record, user: user, bedtime: 1.hour.ago, wake_time: nil)
      end

      start_time = Time.current
      threads = []

      # Mixed operations: clock-ins, clock-outs, and history requests
      threads << Thread.new do
        # New clock-ins
        users[5..7].each do |user|
          post '/api/v1/sleep_records',
            headers: { 'X-USER-ID' => user.id.to_s, 'Content-Type' => 'application/json' }
        end
      end

      threads << Thread.new do
        # Clock-outs - these sessions were created 1 hour ago so current time is fine
        users[0..2].each do |user|
          active_session = user.sleep_records.active.first
          if active_session
            patch "/api/v1/sleep_records/#{active_session.id}",
              headers: { 'X-USER-ID' => user.id.to_s, 'Content-Type' => 'application/json' }
          end
        end
      end

      threads << Thread.new do
        # History requests
        users[8..9].each do |user|
          get '/api/v1/sleep_records',
            headers: { 'X-USER-ID' => user.id.to_s }
        end
      end

      threads.each(&:join)
      total_time = Time.current - start_time

      # Mixed operations should complete in reasonable time
      expect(total_time).to be < 3.0
    end
  end

  describe 'database query optimization' do
    let!(:user) { create(:user, name: 'Query Test User') }

    it 'uses efficient queries for sleep history retrieval' do
      # Create test data
      50.times { |i| create(:sleep_record, user: user, bedtime: (i + 1).hours.ago, wake_time: i.hours.ago) }

      # Monitor query count
      query_count = 0
      ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
        query_count += 1 unless args[4][:sql].match?(/^(BEGIN|COMMIT|ROLLBACK|SELECT.*pg_|SHOW|SET)/)
      end

      get '/api/v1/sleep_records',
        params: { limit: 20 },
        headers: { 'X-USER-ID' => user.id.to_s }

      expect(response).to have_http_status(:ok)

      # Should use minimal queries (N+1 prevention)
      # Expect: 1 query for records, 1 for count, potentially 1 for user validation
      expect(query_count).to be <= 5
    end

    it 'efficiently validates overlapping sessions' do
      # Create one existing session
      create(:sleep_record, user: user, bedtime: 2.hours.ago, wake_time: nil)

      query_count = 0
      ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
        query_count += 1 unless args[4][:sql].match?(/^(BEGIN|COMMIT|ROLLBACK|SELECT.*pg_|SHOW|SET)/)
      end

      # Try to create overlapping session (should fail)
      post '/api/v1/sleep_records',
        params: { bedtime: 1.hour.ago.iso8601 }.to_json,
        headers: { 'X-USER-ID' => user.id.to_s, 'Content-Type' => 'application/json' }

      # Debug if not 422
      unless response.status == 422
        puts "Expected 422, got #{response.status}: #{response.body}"
      end

      expect(response).to have_http_status(:unprocessable_entity)

      # Overlap validation should be efficient (single query for overlap check)
      expect(query_count).to be <= 8 # User find, existing session check, overlap validation, etc.
    end
  end
end
