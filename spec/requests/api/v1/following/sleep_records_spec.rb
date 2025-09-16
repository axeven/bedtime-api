require 'swagger_helper'

RSpec.describe 'api/v1/following/sleep_records', type: :request do
  before do
    host! 'localhost:3000'
  end

  # Include authentication helpers
  include AuthenticationHelpers

  path '/api/v1/following/sleep_records' do
    get('Get sleep records from followed users') do
      tags 'Social Sleep Data'
      description 'Retrieve sleep records from users that the current user follows'
      produces 'application/json'

      parameter name: 'X-USER-ID', in: :header, type: :string, required: true,
                description: 'User ID for authentication'

      response '200', 'Sleep records retrieved successfully' do
        description 'Returns completed sleep records from followed users'
        schema type: :object,
               properties: {
                 sleep_records: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :integer },
                       user_id: { type: :integer },
                       user_name: { type: :string },
                       bedtime: { type: :string, format: 'date-time' },
                       wake_time: { type: :string, format: 'date-time' },
                       duration_minutes: { type: :integer },
                       formatted_duration: { type: :string },
                       sleep_date: { type: :string, format: 'date' },
                       created_at: { type: :string, format: 'date-time' }
                     }
                   }
                 },
                 total_count: { type: :integer }
               }

        context 'with followed users having sleep records' do
          let!(:current_user) { User.create!(name: 'Social User') }
          let!(:followed_user1) { User.create!(name: 'Sleepy User 1') }
          let!(:followed_user2) { User.create!(name: 'Sleepy User 2') }
          let(:'X-USER-ID') { current_user.id.to_s }

          before do
            current_user.follows.create!(following_user: followed_user1)
            current_user.follows.create!(following_user: followed_user2)

            # Create completed sleep records
            followed_user1.sleep_records.create!(
              bedtime: 2.days.ago + 22.hours,
              wake_time: 1.day.ago + 7.hours,
              duration_minutes: 540
            )
            followed_user2.sleep_records.create!(
              bedtime: 1.day.ago + 23.hours,
              wake_time: Time.current + 8.hours,
              duration_minutes: 480
            )
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['sleep_records']).to be_an(Array)
            expect(data['sleep_records'].size).to eq(2)
            expect(data['total_count']).to eq(2)

            # Check record structure
            record = data['sleep_records'].first
            expect(record).to have_key('user_name')
            expect(record).to have_key('duration_minutes')
            expect(record).to have_key('formatted_duration')
          end
        end

        context 'with no followed users' do
          let!(:current_user) { User.create!(name: 'Lonely User') }
          let(:'X-USER-ID') { current_user.id.to_s }

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['sleep_records']).to be_an(Array)
            expect(data['sleep_records']).to be_empty
            expect(data['total_count']).to eq(0)
            expect(data['message']).to include('Follow users to see their sleep data')
          end
        end

        context 'with followed users having no completed records' do
          let!(:current_user) { User.create!(name: 'Social User') }
          let!(:followed_user) { User.create!(name: 'Sleepy User') }
          let(:'X-USER-ID') { current_user.id.to_s }

          before do
            current_user.follows.create!(following_user: followed_user)

            # Create incomplete sleep record (no wake_time)
            followed_user.sleep_records.create!(
              bedtime: 1.day.ago + 22.hours
            )
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['sleep_records']).to be_an(Array)
            expect(data['sleep_records']).to be_empty
            expect(data['total_count']).to eq(0)
            expect(data['message']).to include('No sleep records found')
          end
        end
      end

      response '400', 'Authentication required' do
        schema '$ref' => '#/components/schemas/Error'

        context 'without X-USER-ID header' do
          let(:'X-USER-ID') { nil }
          run_test!
        end
      end

      response '404', 'User not found' do
        schema '$ref' => '#/components/schemas/Error'

        context 'with invalid user ID' do
          let(:'X-USER-ID') { '999999' }
          run_test!
        end
      end
    end
  end
end