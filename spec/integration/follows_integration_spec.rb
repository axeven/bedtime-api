require 'rails_helper'

RSpec.describe 'Following System Integration', type: :request do
  before do
    host! 'localhost:3000'
  end

  describe 'Complete follow/unfollow workflows' do
    let!(:alice) { User.create!(name: 'Alice') }
    let!(:bob) { User.create!(name: 'Bob') }
    let!(:charlie) { User.create!(name: 'Charlie') }

    context 'when User A follows User B' do
      it 'both users can see the relationship in their respective lists' do
        # Alice follows Bob
        post '/api/v1/follows',
             params: { following_user_id: bob.id }.to_json,
             headers: {
               'Content-Type' => 'application/json',
               'X-USER-ID' => alice.id.to_s
             }

        expect(response).to have_http_status(:created)
        follow_data = JSON.parse(response.body)
        expect(follow_data['following_user_id']).to eq(bob.id)
        expect(follow_data['following_user_name']).to eq('Bob')

        # Check Alice's following list
        get '/api/v1/follows',
            headers: { 'X-USER-ID' => alice.id.to_s }

        expect(response).to have_http_status(:ok)
        alice_following = JSON.parse(response.body)
        expect(alice_following['following'].size).to eq(1)
        expect(alice_following['following'][0]['id']).to eq(bob.id)
        expect(alice_following['following'][0]['name']).to eq('Bob')
        expect(alice_following['pagination']['total_count']).to eq(1)

        # Check Bob's followers list
        get '/api/v1/followers',
            headers: { 'X-USER-ID' => bob.id.to_s }

        expect(response).to have_http_status(:ok)
        bob_followers = JSON.parse(response.body)
        expect(bob_followers['followers'].size).to eq(1)
        expect(bob_followers['followers'][0]['id']).to eq(alice.id)
        expect(bob_followers['followers'][0]['name']).to eq('Alice')
        expect(bob_followers['pagination']['total_count']).to eq(1)
      end
    end

    context 'when User A unfollows User B' do
      before do
        alice.follows.create!(following_user: bob)
      end

      it 'removes the relationship from both lists' do
        # Verify relationship exists
        expect(alice.follows.count).to eq(1)
        expect(bob.follower_relationships.count).to eq(1)

        # Alice unfollows Bob
        delete "/api/v1/follows/#{bob.id}",
               headers: { 'X-USER-ID' => alice.id.to_s }

        expect(response).to have_http_status(:no_content)

        # Check Alice's following list is empty
        get '/api/v1/follows',
            headers: { 'X-USER-ID' => alice.id.to_s }

        expect(response).to have_http_status(:ok)
        alice_following = JSON.parse(response.body)
        expect(alice_following['following']).to be_empty
        expect(alice_following['pagination']['total_count']).to eq(0)

        # Check Bob's followers list is empty
        get '/api/v1/followers',
            headers: { 'X-USER-ID' => bob.id.to_s }

        expect(response).to have_http_status(:ok)
        bob_followers = JSON.parse(response.body)
        expect(bob_followers['followers']).to be_empty
        expect(bob_followers['pagination']['total_count']).to eq(0)

        # Verify database consistency
        expect(alice.reload.follows.count).to eq(0)
        expect(bob.reload.follower_relationships.count).to eq(0)
      end
    end

    context 'multiple users following same user (fan-out scenario)' do
      it 'handles multiple followers correctly' do
        # Alice and Charlie both follow Bob
        alice.follows.create!(following_user: bob)
        charlie.follows.create!(following_user: bob)

        # Bob should see both followers
        get '/api/v1/followers',
            headers: { 'X-USER-ID' => bob.id.to_s }

        expect(response).to have_http_status(:ok)
        followers_data = JSON.parse(response.body)
        expect(followers_data['followers'].size).to eq(2)
        expect(followers_data['pagination']['total_count']).to eq(2)

        follower_names = followers_data['followers'].map { |f| f['name'] }
        expect(follower_names).to contain_exactly('Alice', 'Charlie')

        # Verify ordering (most recent first)
        expect(followers_data['followers'][0]['name']).to eq('Charlie')
        expect(followers_data['followers'][1]['name']).to eq('Alice')
      end
    end

    context 'single user following multiple users (fan-in scenario)' do
      it 'handles multiple following relationships correctly' do
        # Alice follows both Bob and Charlie
        alice.follows.create!(following_user: bob)
        alice.follows.create!(following_user: charlie)

        # Alice should see both in following list
        get '/api/v1/follows',
            headers: { 'X-USER-ID' => alice.id.to_s }

        expect(response).to have_http_status(:ok)
        following_data = JSON.parse(response.body)
        expect(following_data['following'].size).to eq(2)
        expect(following_data['pagination']['total_count']).to eq(2)

        following_names = following_data['following'].map { |f| f['name'] }
        expect(following_names).to contain_exactly('Bob', 'Charlie')

        # Verify ordering (most recent first)
        expect(following_data['following'][0]['name']).to eq('Charlie')
        expect(following_data['following'][1]['name']).to eq('Bob')
      end
    end
  end

  describe 'Edge cases and error handling' do
    let!(:alice) { User.create!(name: 'Alice') }
    let!(:bob) { User.create!(name: 'Bob') }

    context 'pagination boundary conditions' do
      before do
        # Create 25 users for Alice to follow
        @users = 25.times.map { |i| User.create!(name: "User#{i}") }
        @users.each { |user| alice.follows.create!(following_user: user) }
      end

      it 'handles pagination correctly at boundaries' do
        # Test first page
        get '/api/v1/follows?limit=20&offset=0',
            headers: { 'X-USER-ID' => alice.id.to_s }

        expect(response).to have_http_status(:ok)
        first_page = JSON.parse(response.body)
        expect(first_page['following'].size).to eq(20)
        expect(first_page['pagination']['total_count']).to eq(25)
        expect(first_page['pagination']['has_more']).to be(true)
        expect(first_page['pagination']['offset']).to eq(0)

        # Test second page
        get '/api/v1/follows?limit=20&offset=20',
            headers: { 'X-USER-ID' => alice.id.to_s }

        expect(response).to have_http_status(:ok)
        second_page = JSON.parse(response.body)
        expect(second_page['following'].size).to eq(5)
        expect(second_page['pagination']['total_count']).to eq(25)
        expect(second_page['pagination']['has_more']).to be(false)
        expect(second_page['pagination']['offset']).to eq(20)

        # Test beyond last page
        get '/api/v1/follows?limit=20&offset=30',
            headers: { 'X-USER-ID' => alice.id.to_s }

        expect(response).to have_http_status(:ok)
        beyond_page = JSON.parse(response.body)
        expect(beyond_page['following']).to be_empty
        expect(beyond_page['pagination']['has_more']).to be(false)
      end

      it 'enforces maximum limit' do
        get '/api/v1/follows?limit=150',
            headers: { 'X-USER-ID' => alice.id.to_s }

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)
        expect(data['pagination']['limit']).to eq(100) # Should be capped at 100
      end
    end

    context 'duplicate and self-follow prevention' do
      it 'prevents duplicate follows' do
        # Create initial follow
        alice.follows.create!(following_user: bob)

        # Attempt duplicate follow
        post '/api/v1/follows',
             params: { following_user_id: bob.id }.to_json,
             headers: {
               'Content-Type' => 'application/json',
               'X-USER-ID' => alice.id.to_s
             }

        expect(response).to have_http_status(:unprocessable_entity)
        error_data = JSON.parse(response.body)
        expect(error_data['error_code']).to eq('DUPLICATE_FOLLOW')
        expect(error_data['error']).to eq('Already following this user')
      end

      it 'prevents self-following' do
        post '/api/v1/follows',
             params: { following_user_id: alice.id }.to_json,
             headers: {
               'Content-Type' => 'application/json',
               'X-USER-ID' => alice.id.to_s
             }

        expect(response).to have_http_status(:unprocessable_entity)
        error_data = JSON.parse(response.body)
        expect(error_data['error_code']).to eq('SELF_FOLLOW_NOT_ALLOWED')
        expect(error_data['error']).to eq('Cannot follow yourself')
      end
    end

    context 'non-existent users' do
      it 'handles following non-existent user' do
        post '/api/v1/follows',
             params: { following_user_id: 999999 }.to_json,
             headers: {
               'Content-Type' => 'application/json',
               'X-USER-ID' => alice.id.to_s
             }

        expect(response).to have_http_status(:not_found)
        error_data = JSON.parse(response.body)
        expect(error_data['error_code']).to eq('USER_NOT_FOUND')
        expect(error_data['error']).to eq('User not found')
      end

      it 'handles unfollowing non-existent user' do
        delete '/api/v1/follows/999999',
               headers: { 'X-USER-ID' => alice.id.to_s }

        expect(response).to have_http_status(:not_found)
        error_data = JSON.parse(response.body)
        expect(error_data['error_code']).to eq('USER_NOT_FOUND')
        expect(error_data['error']).to eq('User not found')
      end

      it 'handles unfollowing user not being followed' do
        delete "/api/v1/follows/#{bob.id}",
               headers: { 'X-USER-ID' => alice.id.to_s }

        expect(response).to have_http_status(:not_found)
        error_data = JSON.parse(response.body)
        expect(error_data['error_code']).to eq('FOLLOW_RELATIONSHIP_NOT_FOUND')
        expect(error_data['error']).to eq('Not following this user')
      end
    end
  end

  describe 'Database consistency' do
    let!(:alice) { User.create!(name: 'Alice') }
    let!(:bob) { User.create!(name: 'Bob') }

    it 'maintains referential integrity' do
      # Create follow relationship
      follow = alice.follows.create!(following_user: bob)

      # Verify both sides of relationship exist
      expect(alice.follows.count).to eq(1)
      expect(bob.follower_relationships.count).to eq(1)
      expect(alice.following_users).to include(bob)
      expect(bob.followers).to include(alice)

      # Delete follow and verify cleanup
      follow.destroy

      expect(alice.reload.follows.count).to eq(0)
      expect(bob.reload.follower_relationships.count).to eq(0)
      expect(alice.following_users).not_to include(bob)
      expect(bob.followers).not_to include(alice)
    end
  end
end