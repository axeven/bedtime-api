require 'swagger_helper'

RSpec.describe 'api/v1/follows', type: :request do
  before do
    host! 'localhost:3000'
  end

  # Include authentication helpers
  include AuthenticationHelpers

  path '/api/v1/follows' do
    post('Follow a user') do
      tags 'Follows'
      description 'Create a new following relationship with another user'
      consumes 'application/json'
      produces 'application/json'

      parameter name: 'X-USER-ID', in: :header, type: :string, required: true,
                description: 'User ID for authentication'
      parameter name: :follow_params, in: :body, required: true,
                description: 'Follow creation payload',
                schema: {
                  type: :object,
                  properties: {
                    following_user_id: {
                      type: :integer,
                      description: 'ID of user to follow',
                      example: 2
                    }
                  },
                  required: ['following_user_id']
                }

      response '201', 'Follow created successfully' do
        description 'Returns the created follow relationship'
        schema type: :object,
               properties: {
                 id: { type: :integer },
                 following_user_id: { type: :integer },
                 following_user_name: { type: :string },
                 created_at: { type: :string, format: 'date-time' }
               }

        let!(:current_user) { User.create!(name: 'Current User') }
        let!(:target_user) { User.create!(name: 'Target User') }
        let(:'X-USER-ID') { current_user.id.to_s }
        let(:follow_params) { { following_user_id: target_user.id } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['following_user_id']).to eq(target_user.id)
          expect(data['following_user_name']).to eq('Target User')
          expect(data['id']).to be_present
          expect(data['created_at']).to be_present
        end
      end

      response '400', 'Authentication required' do
        schema '$ref' => '#/components/schemas/Error'

        let!(:target_user) { User.create!(name: 'Target User') }
        let(:follow_params) { { following_user_id: target_user.id } }

        context 'without X-USER-ID header' do
          let(:'X-USER-ID') { nil }

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['error_code']).to eq('MISSING_USER_ID')
          end
        end
      end

      response '404', 'User not found' do
        schema '$ref' => '#/components/schemas/Error'

        let!(:current_user) { User.create!(name: 'Current User') }
        let(:'X-USER-ID') { current_user.id.to_s }
        let(:follow_params) { { following_user_id: 999999 } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error_code']).to eq('USER_NOT_FOUND')
          expect(data['error']).to eq('User not found')
        end
      end

      response '422', 'Cannot follow self or duplicate follow' do
        schema '$ref' => '#/components/schemas/Error'

        context 'attempting to follow self' do
          let!(:current_user) { User.create!(name: 'Self User') }
          let(:'X-USER-ID') { current_user.id.to_s }
          let(:follow_params) { { following_user_id: current_user.id } }

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['error_code']).to eq('SELF_FOLLOW_NOT_ALLOWED')
            expect(data['error']).to eq('Cannot follow yourself')
          end
        end

        context 'attempting duplicate follow' do
          let!(:current_user) { User.create!(name: 'Current User') }
          let!(:target_user) { User.create!(name: 'Target User') }
          let(:'X-USER-ID') { current_user.id.to_s }
          let(:follow_params) { { following_user_id: target_user.id } }

          before do
            current_user.follows.create!(following_user: target_user)
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['error_code']).to eq('DUPLICATE_FOLLOW')
            expect(data['error']).to eq('Already following this user')
          end
        end
      end
    end

    get('Get following list') do
      tags 'Follows'
      description 'Retrieve list of users that the current user is following'
      produces 'application/json'

      parameter name: 'X-USER-ID', in: :header, type: :string, required: true,
                description: 'User ID for authentication'
      parameter name: :limit, in: :query, type: :integer, required: false,
                description: 'Number of results (max 100, default 20)'
      parameter name: :offset, in: :query, type: :integer, required: false,
                description: 'Starting position (default 0)'

      response '200', 'Following list retrieved successfully' do
        description 'Returns list of users being followed with pagination'
        schema type: :object,
               properties: {
                 following: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :integer },
                       name: { type: :string },
                       followed_at: { type: :string, format: 'date-time' }
                     }
                   }
                 },
                 pagination: {
                   type: :object,
                   properties: {
                     total_count: { type: :integer },
                     limit: { type: :integer },
                     offset: { type: :integer },
                     has_more: { type: :boolean }
                   }
                 }
               }

        context 'with following relationships' do
          let!(:current_user) { User.create!(name: 'Current User') }
          let!(:user1) { User.create!(name: 'User One') }
          let!(:user2) { User.create!(name: 'User Two') }
          let!(:user3) { User.create!(name: 'User Three') }
          let(:'X-USER-ID') { current_user.id.to_s }

          before do
            current_user.follows.create!(following_user: user1)
            sleep(0.01) # Ensure different timestamps
            current_user.follows.create!(following_user: user2)
            sleep(0.01)
            current_user.follows.create!(following_user: user3)
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['following']).to be_an(Array)
            expect(data['following'].size).to eq(3)
            expect(data['pagination']['total_count']).to eq(3)
            expect(data['pagination']['limit']).to eq(20)
            expect(data['pagination']['offset']).to eq(0)
            expect(data['pagination']['has_more']).to be(false)

            # Check ordering (most recent first)
            expect(data['following'][0]['name']).to eq('User Three')
            expect(data['following'][1]['name']).to eq('User Two')
            expect(data['following'][2]['name']).to eq('User One')

            # Check structure
            data['following'].each do |user|
              expect(user).to have_key('id')
              expect(user).to have_key('name')
              expect(user).to have_key('followed_at')
            end
          end
        end

        context 'with pagination' do
          let!(:current_user) { User.create!(name: 'Current User') }
          let!(:user1) { User.create!(name: 'User One') }
          let!(:user2) { User.create!(name: 'User Two') }
          let(:'X-USER-ID') { current_user.id.to_s }
          let(:limit) { 1 }
          let(:offset) { 0 }

          before do
            current_user.follows.create!(following_user: user1)
            sleep(0.01)
            current_user.follows.create!(following_user: user2)
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['following'].size).to eq(1)
            expect(data['pagination']['total_count']).to eq(2)
            expect(data['pagination']['limit']).to eq(1)
            expect(data['pagination']['offset']).to eq(0)
            expect(data['pagination']['has_more']).to be(true)
          end
        end

        context 'with no following relationships' do
          let!(:current_user) { User.create!(name: 'Lonely User') }
          let(:'X-USER-ID') { current_user.id.to_s }

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['following']).to be_an(Array)
            expect(data['following']).to be_empty
            expect(data['pagination']['total_count']).to eq(0)
            expect(data['pagination']['has_more']).to be(false)
          end
        end
      end

      response '400', 'Authentication required' do
        schema '$ref' => '#/components/schemas/Error'

        context 'without X-USER-ID header' do
          let(:'X-USER-ID') { nil }

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['error_code']).to eq('MISSING_USER_ID')
          end
        end
      end
    end
  end

  path '/api/v1/follows/{following_user_id}' do
    delete('Unfollow a user') do
      tags 'Follows'
      description 'Remove a following relationship with another user'
      produces 'application/json'

      parameter name: 'X-USER-ID', in: :header, type: :string, required: true,
                description: 'User ID for authentication'
      parameter name: :following_user_id, in: :path, type: :integer, required: true,
                description: 'ID of user to unfollow'

      response '204', 'Successfully unfollowed user' do
        let!(:current_user) { User.create!(name: 'Current User') }
        let!(:target_user) { User.create!(name: 'Target User') }
        let(:'X-USER-ID') { current_user.id.to_s }
        let(:following_user_id) { target_user.id }

        before do
          current_user.follows.create!(following_user: target_user)
        end

        run_test! do |response|
          expect(response.body).to be_empty
          expect(current_user.follows.find_by(following_user: target_user)).to be_nil
        end
      end

      response '400', 'Authentication required' do
        schema '$ref' => '#/components/schemas/Error'

        let!(:target_user) { User.create!(name: 'Target User') }
        let(:following_user_id) { target_user.id }

        context 'without X-USER-ID header' do
          let(:'X-USER-ID') { nil }

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['error_code']).to eq('MISSING_USER_ID')
          end
        end
      end

      response '404', 'User not found or not following' do
        schema '$ref' => '#/components/schemas/Error'

        context 'unfollowing non-existent user' do
          let!(:current_user) { User.create!(name: 'Current User') }
          let(:'X-USER-ID') { current_user.id.to_s }
          let(:following_user_id) { 999999 }

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['error_code']).to eq('USER_NOT_FOUND')
            expect(data['error']).to eq('User not found')
          end
        end

        context 'unfollowing user not being followed' do
          let!(:current_user) { User.create!(name: 'Current User') }
          let!(:target_user) { User.create!(name: 'Target User') }
          let(:'X-USER-ID') { current_user.id.to_s }
          let(:following_user_id) { target_user.id }

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['error_code']).to eq('FOLLOW_RELATIONSHIP_NOT_FOUND')
            expect(data['error']).to eq('Not following this user')
          end
        end
      end
    end
  end
end