require 'rails_helper'

RSpec.describe 'API V1 Follows Caching', type: :request do
  let(:user) { create(:user) }
  let(:following_user1) { create(:user) }
  let(:following_user2) { create(:user) }
  let(:headers) { { 'X-USER-ID' => user.id.to_s, 'Content-Type' => 'application/json' } }

  before(:each) do
    Rails.cache.clear
  end

  describe 'GET /api/v1/follows' do
    context 'with cache miss' do
      it 'returns data and indicates cache miss' do
        create(:follow, user: user, following_user: following_user1)
        create(:follow, user: user, following_user: following_user2)

        get '/api/v1/follows', headers: headers

        expect(response).to have_http_status(:ok)
        response_data = JSON.parse(response.body)

        expect(response_data['following']).to be_an(Array)
        expect(response_data['following'].length).to eq(2)
        expect(response_data['cache_info']['cached']).to be_falsey
        expect(response_data['cache_info']['cache_key']).to include('following_list:user:')
      end
    end

    context 'with cache hit' do
      it 'returns cached data on subsequent requests' do
        create(:follow, user: user, following_user: following_user1)

        # First request - cache miss
        get '/api/v1/follows', headers: headers
        first_response = JSON.parse(response.body)
        expect(first_response['cache_info']['cached']).to be_falsey

        # Second request - cache hit
        get '/api/v1/follows', headers: headers
        second_response = JSON.parse(response.body)
        expect(second_response['cache_info']['cached']).to be_truthy

        # Data should be identical
        expect(first_response['following']).to eq(second_response['following'])
      end
    end

    context 'with different pagination parameters' do
      it 'creates separate cache entries for different pagination' do
        (1..5).each { |i| create(:follow, user: user, following_user: create(:user, name: "User #{i}")) }

        # Request with default pagination
        get '/api/v1/follows', headers: headers
        default_response = JSON.parse(response.body)

        # Request with different pagination
        get '/api/v1/follows?limit=2&offset=1', headers: headers
        paginated_response = JSON.parse(response.body)

        expect(default_response['cache_info']['cache_key']).to include(':20_0')
        expect(paginated_response['cache_info']['cache_key']).to include(':2_1')
        expect(default_response['following'].length).to eq(5)
        expect(paginated_response['following'].length).to eq(2)
      end
    end
  end

  describe 'POST /api/v1/follows' do
    it 'invalidates cache after creating follow' do
      # Warm cache
      get '/api/v1/follows', headers: headers
      first_response = JSON.parse(response.body)
      expect(first_response['following']).to be_empty

      # Create follow
      post '/api/v1/follows', headers: headers, params: { following_user_id: following_user1.id }.to_json
      expect(response).to have_http_status(:created)

      # Verify cache was invalidated by checking if next request is a cache miss
      get '/api/v1/follows', headers: headers
      after_follow_response = JSON.parse(response.body)

      expect(after_follow_response['following'].length).to eq(1)
      expect(after_follow_response['following'][0]['id']).to eq(following_user1.id)
    end
  end

  describe 'DELETE /api/v1/follows/:id' do
    it 'invalidates cache after destroying follow' do
      follow = create(:follow, user: user, following_user: following_user1)

      # Warm cache
      get '/api/v1/follows', headers: headers
      first_response = JSON.parse(response.body)
      expect(first_response['following'].length).to eq(1)

      # Delete follow
      delete "/api/v1/follows/#{following_user1.id}", headers: headers
      expect(response).to have_http_status(:no_content)

      # Verify cache was invalidated
      get '/api/v1/follows', headers: headers
      after_delete_response = JSON.parse(response.body)

      expect(after_delete_response['following']).to be_empty
    end
  end

  describe 'cache invalidation patterns' do
    it 'invalidates related cache entries when following relationships change' do
      follower_headers = { 'X-USER-ID' => following_user1.id.to_s }

      # Warm caches for both users
      get '/api/v1/follows', headers: headers  # user's following list
      get '/api/v1/followers', headers: follower_headers  # following_user1's followers list

      # Create follow relationship
      post '/api/v1/follows', headers: headers, params: { following_user_id: following_user1.id }.to_json
      expect(response).to have_http_status(:created)

      # Check both caches were updated
      get '/api/v1/follows', headers: headers
      following_response = JSON.parse(response.body)
      expect(following_response['following'].length).to eq(1)

      get '/api/v1/followers', headers: follower_headers
      followers_response = JSON.parse(response.body)
      expect(followers_response['followers'].length).to eq(1)
    end
  end
end
