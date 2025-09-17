require 'swagger_helper'

RSpec.describe 'api/v1/followers', type: :request do
  before do
    host! 'localhost:3000'
  end

  # Include authentication helpers
  include AuthenticationHelpers

  path '/api/v1/followers' do
    get('Get followers list') do
      tags 'Followers'
      description 'Retrieve list of users following the current user'
      produces 'application/json'

      parameter name: 'X-USER-ID', in: :header, type: :string, required: true,
                description: 'User ID for authentication'
      parameter name: :limit, in: :query, type: :integer, required: false,
                description: 'Number of results (max 100, default 20)'
      parameter name: :offset, in: :query, type: :integer, required: false,
                description: 'Starting position (default 0)'

      response '200', 'Followers list retrieved successfully' do
        description 'Returns list of users following the current user with pagination'
        schema type: :object,
               properties: {
                 followers: {
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

        context 'with followers' do
          let!(:current_user) { User.create!(name: 'Popular User') }
          let!(:follower1) { User.create!(name: 'Follower One') }
          let!(:follower2) { User.create!(name: 'Follower Two') }
          let!(:follower3) { User.create!(name: 'Follower Three') }
          let(:'X-USER-ID') { current_user.id.to_s }

          before do
            follower1.follows.create!(following_user: current_user)
            sleep(0.01) # Ensure different timestamps
            follower2.follows.create!(following_user: current_user)
            sleep(0.01)
            follower3.follows.create!(following_user: current_user)
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['followers']).to be_an(Array)
            expect(data['followers'].size).to eq(3)
            expect(data['pagination']['total_count']).to eq(3)
            expect(data['pagination']['limit']).to eq(20)
            expect(data['pagination']['offset']).to eq(0)
            expect(data['pagination']['has_more']).to be(false)

            # Check ordering (most recent followers first)
            expect(data['followers'][0]['name']).to eq('Follower Three')
            expect(data['followers'][1]['name']).to eq('Follower Two')
            expect(data['followers'][2]['name']).to eq('Follower One')

            # Check structure
            data['followers'].each do |user|
              expect(user).to have_key('id')
              expect(user).to have_key('name')
              expect(user).to have_key('followed_at')
            end
          end
        end

        context 'with pagination' do
          let!(:current_user) { User.create!(name: 'Popular User') }
          let!(:follower1) { User.create!(name: 'Follower One') }
          let!(:follower2) { User.create!(name: 'Follower Two') }
          let(:'X-USER-ID') { current_user.id.to_s }
          let(:limit) { 1 }
          let(:offset) { 0 }

          before do
            follower1.follows.create!(following_user: current_user)
            sleep(0.01)
            follower2.follows.create!(following_user: current_user)
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['followers'].size).to eq(1)
            expect(data['pagination']['total_count']).to eq(2)
            expect(data['pagination']['limit']).to eq(1)
            expect(data['pagination']['offset']).to eq(0)
            expect(data['pagination']['has_more']).to be(true)
          end
        end

        context 'with no followers' do
          let!(:current_user) { User.create!(name: 'Lonely User') }
          let(:'X-USER-ID') { current_user.id.to_s }

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['followers']).to be_an(Array)
            expect(data['followers']).to be_empty
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
end
