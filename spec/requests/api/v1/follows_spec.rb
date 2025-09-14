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
  end
end