require 'rails_helper'

RSpec.describe 'Database Persistence', type: :request do
  describe 'data survives application restarts' do
    let!(:user) { create(:user, name: 'Persistent User') }

    it 'maintains sleep records after simulated restart' do
      # Create a completed sleep record
      completed_record = create(:sleep_record,
        user: user,
        bedtime: 2.hours.ago,
        wake_time: 1.hour.ago
      )

      # Create an active sleep record
      post '/api/v1/sleep_records',
        headers: { 'X-USER-ID' => user.id.to_s, 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:created)
      active_record_id = JSON.parse(response.body)['id']

      # Simulate restart by clearing ActiveRecord connection cache
      # and forcing database reconnection (Rails 8 compatible)
      ActiveRecord::Base.connection_pool.disconnect!
      ActiveRecord::Base.establish_connection

      # Verify completed record persists
      get '/api/v1/sleep_records',
        headers: { 'X-USER-ID' => user.id.to_s }

      expect(response).to have_http_status(:ok)
      records = JSON.parse(response.body)['sleep_records']

      # Should find both the factory-created completed record and the API-created active record
      expect(records.length).to eq(2)

      completed = records.find { |r| r['id'] == completed_record.id }
      active = records.find { |r| r['id'] == active_record_id }

      expect(completed).to be_present
      expect(completed['active']).to be false
      expect(completed['duration_minutes']).to be_present

      expect(active).to be_present
      expect(active['active']).to be true
      expect(active['duration_minutes']).to be_nil
    end

    it 'maintains user data integrity after restart' do
      # Create user and record through API
      post '/api/v1/users',
        params: { user: { name: 'Restart Test User' } },
        headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:created)
      created_user_id = JSON.parse(response.body)['id']

      # Simulate restart
      ActiveRecord::Base.connection_pool.disconnect!
      ActiveRecord::Base.establish_connection

      # Verify user still exists and can be used
      post '/api/v1/sleep_records',
        headers: { 'X-USER-ID' => created_user_id.to_s, 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:created)

      record_data = JSON.parse(response.body)
      expect(record_data['user_id']).to eq(created_user_id)
    end

    it 'handles database reconnection gracefully' do
      # Create initial data
      post '/api/v1/sleep_records',
        headers: { 'X-USER-ID' => user.id.to_s, 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:created)

      # Force multiple reconnections by clearing connections multiple times
      3.times do
        ActiveRecord::Base.connection_pool.disconnect!
        ActiveRecord::Base.establish_connection

        # Each time, verify the API still works
        get '/api/v1/sleep_records/current',
          headers: { 'X-USER-ID' => user.id.to_s }
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'transaction integrity' do
    let!(:user) { create(:user, name: 'Transaction User') }

    it 'maintains data consistency during concurrent operations' do
      # Test that overlapping session validation works even with concurrent requests
      threads = []
      results = []

      # Try to create multiple sessions concurrently (should only succeed once due to overlap validation)
      5.times do |i|
        threads << Thread.new do
          begin
            post '/api/v1/sleep_records',
              headers: { 'X-USER-ID' => user.id.to_s, 'Content-Type' => 'application/json' }
            results << { status: response.status, thread: i }
          rescue => e
            results << { error: e.message, thread: i }
          end
        end
      end

      threads.each(&:join)

      # Should have exactly one success and rest should fail due to overlapping session validation
      successful_requests = results.select { |r| r[:status] == 201 }
      expect(successful_requests.length).to eq(1)

      # Verify database state is consistent
      active_sessions = user.sleep_records.active
      expect(active_sessions.count).to eq(1)
    end
  end
end
