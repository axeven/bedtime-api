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
      parameter name: :days, in: :query, type: :integer, required: false,
                description: 'Number of days to look back (1-30, default 7)'

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
                 total_count: { type: :integer },
                 date_range: {
                   type: :object,
                   properties: {
                     days_back: { type: :integer },
                     from_date: { type: :string, format: 'date' },
                     to_date: { type: :string, format: 'date' }
                   }
                 }
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

            # Check date_range structure
            expect(data['date_range']).to be_present
            expect(data['date_range']['days_back']).to eq(7)
            expect(data['date_range']['from_date']).to be_present
            expect(data['date_range']['to_date']).to be_present
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

            # Check date_range structure for empty results
            expect(data['date_range']).to be_present
            expect(data['date_range']['days_back']).to eq(7)
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

            # Check date_range structure for empty results
            expect(data['date_range']).to be_present
            expect(data['date_range']['days_back']).to eq(7)
          end
        end

        context 'with custom date range' do
          let!(:current_user) { User.create!(name: 'Date Range User') }
          let!(:followed_user) { User.create!(name: 'Date Range Sleeper') }
          let(:'X-USER-ID') { current_user.id.to_s }
          let(:days) { 3 }

          before do
            current_user.follows.create!(following_user: followed_user)

            # Create sleep records - some within range, some outside
            followed_user.sleep_records.create!(
              bedtime: 2.days.ago + 22.hours,
              wake_time: 2.days.ago + 30.hours,
              duration_minutes: 480
            )
            followed_user.sleep_records.create!(
              bedtime: 5.days.ago + 22.hours,
              wake_time: 5.days.ago + 30.hours,
              duration_minutes: 480
            )
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['sleep_records'].size).to eq(1) # Only record within 3 days
            expect(data['date_range']['days_back']).to eq(3)
            expect(data['date_range']['from_date']).to be_present
            expect(data['date_range']['to_date']).to be_present
          end
        end

        context 'with records outside date range' do
          let!(:current_user) { User.create!(name: 'Range Test User') }
          let!(:followed_user) { User.create!(name: 'Range Test Sleeper') }
          let(:'X-USER-ID') { current_user.id.to_s }
          let(:days) { 1 }

          before do
            current_user.follows.create!(following_user: followed_user)

            # Create sleep record outside 1 day range
            followed_user.sleep_records.create!(
              bedtime: 3.days.ago + 22.hours,
              wake_time: 3.days.ago + 30.hours,
              duration_minutes: 480
            )
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['sleep_records']).to be_empty
            expect(data['total_count']).to eq(0)
            expect(data['date_range']['days_back']).to eq(1)
            expect(data['message']).to include('No sleep records found in the last 1 days')
          end
        end
      end

      response '400', 'Bad request' do
        schema '$ref' => '#/components/schemas/Error'

        context 'with invalid date range parameters' do
          let!(:current_user) { User.create!(name: 'Valid User') }
          let(:'X-USER-ID') { current_user.id.to_s }

          context 'days parameter too large' do
            let(:days) { 50 }

            run_test! do |response|
              data = JSON.parse(response.body)
              expect(data['error_code']).to eq('INVALID_DATE_RANGE')
              expect(data['error']).to include('Date range must be between 1 and 30 days')
            end
          end

          context 'days parameter too small' do
            let(:days) { 0 }

            run_test! do |response|
              data = JSON.parse(response.body)
              expect(data['error_code']).to eq('INVALID_DATE_RANGE')
              expect(data['error']).to include('Date range must be between 1 and 30 days')
            end
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