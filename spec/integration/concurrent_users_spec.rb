require 'rails_helper'

RSpec.describe 'Concurrent Users API Workflow', type: :request do
  let!(:user1) { create(:user, name: 'User 1') }
  let!(:user2) { create(:user, name: 'User 2') }

  describe 'multiple users can use sleep tracking independently' do
    it 'allows concurrent clock-ins for different users' do
      # Both users clock in at the same time
      post '/api/v1/sleep_records',
        headers: { 'X-USER-ID' => user1.id.to_s, 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:created)
      user1_response = JSON.parse(response.body)

      post '/api/v1/sleep_records',
        headers: { 'X-USER-ID' => user2.id.to_s, 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:created)
      user2_response = JSON.parse(response.body)

      # Both should have active sessions
      expect(user1_response['active']).to be true
      expect(user2_response['active']).to be true
      expect(user1_response['user_id']).to eq(user1.id)
      expect(user2_response['user_id']).to eq(user2.id)
    end

    it 'maintains separate session states for different users' do
      # User 1 clocks in with bedtime 2 minutes ago to allow for valid clock-out
      post '/api/v1/sleep_records',
        params: { bedtime: 2.minutes.ago.iso8601 }.to_json,
        headers: { 'X-USER-ID' => user1.id.to_s, 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:created)
      user1_session_id = JSON.parse(response.body)['id']

      # User 2 clocks in
      post '/api/v1/sleep_records',
        headers: { 'X-USER-ID' => user2.id.to_s, 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:created)
      user2_session_id = JSON.parse(response.body)['id']

      # User 1 clocks out - current time will provide 2+ minute duration
      patch "/api/v1/sleep_records/#{user1_session_id}",
        headers: { 'X-USER-ID' => user1.id.to_s, 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:ok)

      # User 1 should have no active session
      get '/api/v1/sleep_records/current',
        headers: { 'X-USER-ID' => user1.id.to_s }
      expect(response).to have_http_status(:not_found)

      # User 2 should still have active session
      get '/api/v1/sleep_records/current',
        headers: { 'X-USER-ID' => user2.id.to_s }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['id']).to eq(user2_session_id)
    end

    it 'prevents users from accessing other users data' do
      # User 1 creates a session
      post '/api/v1/sleep_records',
        headers: { 'X-USER-ID' => user1.id.to_s, 'Content-Type' => 'application/json' }
      user1_session_id = JSON.parse(response.body)['id']

      # User 2 tries to access User 1's session
      patch "/api/v1/sleep_records/#{user1_session_id}",
        headers: { 'X-USER-ID' => user2.id.to_s, 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:not_found)

      # User 2 tries to view User 1's sleep history
      get '/api/v1/sleep_records',
        headers: { 'X-USER-ID' => user2.id.to_s }

      user2_history = JSON.parse(response.body)['sleep_records']
      expect(user2_history).to be_empty # User 2 should see no records
    end

    it 'handles concurrent sleep history requests efficiently' do
      # Create some sleep records for both users
      5.times do |i|
        create(:sleep_record,
          user: user1,
          bedtime: (i + 1).hours.ago,
          wake_time: i.hours.ago
        )
        create(:sleep_record,
          user: user2,
          bedtime: (i + 1).hours.ago,
          wake_time: i.hours.ago
        )
      end

      # Both users request their history simultaneously
      threads = []

      threads << Thread.new do
        get '/api/v1/sleep_records',
          headers: { 'X-USER-ID' => user1.id.to_s }
        expect(response).to have_http_status(:ok)
        user1_records = JSON.parse(response.body)['sleep_records']
        expect(user1_records.length).to eq(5)
        user1_records.each { |record| expect(record['user_id']).to eq(user1.id) }
      end

      threads << Thread.new do
        get '/api/v1/sleep_records',
          headers: { 'X-USER-ID' => user2.id.to_s }
        expect(response).to have_http_status(:ok)
        user2_records = JSON.parse(response.body)['sleep_records']
        expect(user2_records.length).to eq(5)
        user2_records.each { |record| expect(record['user_id']).to eq(user2.id) }
      end

      threads.each(&:join)
    end
  end
end
