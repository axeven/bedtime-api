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
      parameter name: :sort_by, in: :query, type: :string, required: false,
                description: 'Sort field: duration, bedtime, wake_time, created_at (default: duration)'
      parameter name: :limit, in: :query, type: :integer, required: false,
                description: 'Number of results per page (1-100, default 20)'
      parameter name: :offset, in: :query, type: :integer, required: false,
                description: 'Starting position (default 0)'

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
                       created_at: { type: :string, format: 'date-time' },
                       record_complete: { type: :boolean }
                     }
                   }
                 },
                 pagination: {
                   type: :object,
                   properties: {
                     total_count: { type: :integer },
                     current_count: { type: :integer },
                     limit: { type: :integer },
                     offset: { type: :integer },
                     has_more: { type: :boolean },
                     next_offset: { type: :integer, nullable: true },
                     previous_offset: { type: :integer, nullable: true }
                   }
                 },
                 statistics: {
                   type: :object,
                   properties: {
                     total_records: { type: :integer },
                     unique_users: { type: :integer },
                     duration_stats: {
                       type: :object,
                       properties: {
                         average_minutes: { type: :integer },
                         longest_minutes: { type: :integer },
                         shortest_minutes: { type: :integer },
                         total_sleep_hours: { type: :number }
                       }
                     }
                   }
                 },
                 date_range: {
                   type: :object,
                   properties: {
                     days_back: { type: :integer },
                     from_date: { type: :string, format: 'date' },
                     to_date: { type: :string, format: 'date' }
                   }
                 },
                 sorting: {
                   type: :object,
                   properties: {
                     sort_by: { type: :string }
                   }
                 },
                 privacy_info: {
                   type: :object,
                   properties: {
                     data_source: { type: :string },
                     record_types: { type: :string },
                     your_records_included: { type: :boolean },
                     following_count: { type: :integer }
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
              bedtime: 1.day.ago + 22.hours,
              wake_time: 1.day.ago + 31.hours,
              duration_minutes: 540
            )
            followed_user2.sleep_records.create!(
              bedtime: 1.day.ago + 23.hours,
              wake_time: 1.day.ago + 31.hours,
              duration_minutes: 480
            )
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['sleep_records']).to be_an(Array)
            expect(data['sleep_records'].size).to eq(2)
            expect(data['pagination']['total_count']).to eq(2)

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

            # Check statistics structure
            expect(data['statistics']).to be_present
            expect(data['statistics']['total_records']).to eq(2)
            expect(data['statistics']['unique_users']).to eq(2)
            expect(data['statistics']['duration_stats']['average_minutes']).to be_a(Integer)
            expect(data['statistics']['duration_stats']['longest_minutes']).to eq(540)
            expect(data['statistics']['duration_stats']['shortest_minutes']).to eq(480)

            # Check sorting structure
            expect(data['sorting']).to be_present
            expect(data['sorting']['sort_by']).to eq('duration')

            # Check privacy structure
            expect(data['privacy_info']).to be_present
            expect(data['privacy_info']['data_source']).to eq('followed_users_only')
            expect(data['privacy_info']['record_types']).to eq('completed_records_only')
            expect(data['privacy_info']['your_records_included']).to be(false)
            expect(data['privacy_info']['following_count']).to eq(2)

            # Check record_complete field
            expect(data['sleep_records'][0]['record_complete']).to be(true)
          end
        end

        context 'with no followed users' do
          let!(:current_user) { User.create!(name: 'Lonely User') }
          let(:'X-USER-ID') { current_user.id.to_s }

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['sleep_records']).to be_an(Array)
            expect(data['sleep_records']).to be_empty
            expect(data['pagination']['total_count']).to eq(0)
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
            expect(data['pagination']['total_count']).to eq(0)
            expect(data['message']).to include('No completed sleep records found')

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
            expect(data['pagination']['total_count']).to eq(0)
            expect(data['date_range']['days_back']).to eq(1)
            expect(data['message']).to include('No completed sleep records found from the 1 users you follow in the last 1 days')
          end
        end

        context 'with custom sorting by duration' do
          let!(:current_user) { User.create!(name: 'Sort Test User') }
          let!(:followed_user1) { User.create!(name: 'Short Sleeper') }
          let!(:followed_user2) { User.create!(name: 'Long Sleeper') }
          let(:'X-USER-ID') { current_user.id.to_s }
          let(:sort_by) { 'duration' }

          before do
            current_user.follows.create!(following_user: followed_user1)
            current_user.follows.create!(following_user: followed_user2)

            # Create records with different durations
            followed_user1.sleep_records.create!(
              bedtime: 1.day.ago + 22.hours,
              wake_time: 1.day.ago + 28.hours,
              duration_minutes: 360 # 6 hours
            )
            followed_user2.sleep_records.create!(
              bedtime: 1.day.ago + 21.hours,
              wake_time: 1.day.ago + 29.hours,
              duration_minutes: 480 # 8 hours
            )
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['sleep_records'].size).to eq(2)
            expect(data['sorting']['sort_by']).to eq('duration')

            # Check that records are sorted by duration (longest first)
            expect(data['sleep_records'][0]['duration_minutes']).to eq(480)
            expect(data['sleep_records'][1]['duration_minutes']).to eq(360)

            # Check statistics
            expect(data['statistics']['duration_stats']['longest_minutes']).to eq(480)
            expect(data['statistics']['duration_stats']['shortest_minutes']).to eq(360)
            expect(data['statistics']['duration_stats']['average_minutes']).to eq(420)
          end
        end

        context 'with custom sorting by bedtime' do
          let!(:current_user) { User.create!(name: 'Bedtime Sort User') }
          let!(:followed_user) { User.create!(name: 'Variable Bedtime User') }
          let(:'X-USER-ID') { current_user.id.to_s }
          let(:sort_by) { 'bedtime' }

          before do
            current_user.follows.create!(following_user: followed_user)

            # Create records with different bedtimes
            followed_user.sleep_records.create!(
              bedtime: 2.days.ago + 22.hours,
              wake_time: 2.days.ago + 30.hours,
              duration_minutes: 480
            )
            followed_user.sleep_records.create!(
              bedtime: 1.day.ago + 21.hours,
              wake_time: 1.day.ago + 29.hours,
              duration_minutes: 480
            )
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['sleep_records'].size).to eq(2)
            expect(data['sorting']['sort_by']).to eq('bedtime')

            # Check that records are sorted by bedtime (most recent first)
            first_bedtime = Time.parse(data['sleep_records'][0]['bedtime'])
            second_bedtime = Time.parse(data['sleep_records'][1]['bedtime'])
            expect(first_bedtime).to be > second_bedtime
          end
        end

        context 'with multiple records per user' do
          let!(:current_user) { User.create!(name: 'Multi Record User') }
          let!(:followed_user) { User.create!(name: 'Prolific Sleeper') }
          let(:'X-USER-ID') { current_user.id.to_s }

          before do
            current_user.follows.create!(following_user: followed_user)

            # Create multiple records for the same user
            3.times do |i|
              followed_user.sleep_records.create!(
                bedtime: (i + 1).days.ago + 22.hours,
                wake_time: (i + 1).days.ago + (22 + 6 + i).hours,
                duration_minutes: 360 + (i * 60) # Different durations: 360, 420, 480
              )
            end
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['sleep_records'].size).to eq(3)
            expect(data['statistics']['total_records']).to eq(3)
            expect(data['statistics']['unique_users']).to eq(1)

            # Check that all records are from the same user but multiple records allowed
            user_ids = data['sleep_records'].map { |record| record['user_id'] }.uniq
            expect(user_ids.size).to eq(1)
          end
        end

        context 'privacy controls validation' do
          let!(:current_user) { User.create!(name: 'Privacy User') }
          let!(:followed_user) { User.create!(name: 'Followed User') }
          let!(:non_followed_user) { User.create!(name: 'Non-Followed User') }
          let(:'X-USER-ID') { current_user.id.to_s }

          before do
            current_user.follows.create!(following_user: followed_user)

            # Create complete record for followed user (should be included)
            followed_user.sleep_records.create!(
              bedtime: 1.day.ago + 22.hours,
              wake_time: 1.day.ago + 30.hours,
              duration_minutes: 480
            )

            # Create complete record for non-followed user (should be excluded)
            non_followed_user.sleep_records.create!(
              bedtime: 1.day.ago + 23.hours,
              wake_time: 1.day.ago + 31.hours,
              duration_minutes: 540
            )

            # Create incomplete record for followed user (should be excluded)
            followed_user.sleep_records.create!(
              bedtime: 1.day.ago + 21.hours,
              wake_time: nil,
              duration_minutes: nil
            )

            # Create current user's own record (should be excluded from social feed)
            current_user.sleep_records.create!(
              bedtime: 1.day.ago + 22.5.hours,
              wake_time: 1.day.ago + 30.5.hours,
              duration_minutes: 500
            )
          end

          run_test! do |response|
            data = JSON.parse(response.body)

            # Should only include the complete record from followed user
            expect(data['sleep_records'].size).to eq(1)
            expect(data['sleep_records'][0]['user_id']).to eq(followed_user.id)
            expect(data['sleep_records'][0]['duration_minutes']).to eq(480)
            expect(data['sleep_records'][0]['record_complete']).to be(true)

            # Privacy info should be accurate
            expect(data['privacy_info']['data_source']).to eq('followed_users_only')
            expect(data['privacy_info']['record_types']).to eq('completed_records_only')
            expect(data['privacy_info']['your_records_included']).to be(false)
            expect(data['privacy_info']['following_count']).to eq(1)

            # Statistics should only include the one valid record
            expect(data['statistics']['total_records']).to eq(1)
            expect(data['statistics']['unique_users']).to eq(1)
            expect(data['statistics']['duration_stats']['longest_minutes']).to eq(480)
          end
        end

        context 'complete records filtering' do
          let!(:current_user) { User.create!(name: 'Complete Records User') }
          let!(:followed_user) { User.create!(name: 'Incomplete Sleeper') }
          let(:'X-USER-ID') { current_user.id.to_s }

          before do
            current_user.follows.create!(following_user: followed_user)

            # Create incomplete record (missing wake_time)
            followed_user.sleep_records.create!(
              bedtime: 1.day.ago + 22.hours,
              wake_time: nil,
              duration_minutes: nil
            )

            # Create record and manually set duration_minutes to nil after creation
            incomplete_record = followed_user.sleep_records.create!(
              bedtime: 1.day.ago + 20.hours,
              wake_time: 1.day.ago + 28.hours
            )
            # Manually set duration_minutes to nil to test filtering
            incomplete_record.update_column(:duration_minutes, nil)
          end

          run_test! do |response|
            data = JSON.parse(response.body)

            # Should exclude all incomplete records
            expect(data['sleep_records']).to be_empty
            expect(data['pagination']['total_count']).to eq(0)

            # Message should indicate no completed records
            expect(data['message']).to include('No completed sleep records found')
            expect(data['privacy_info']['following_count']).to eq(1)
          end
        end

        context 'with pagination' do
          let!(:current_user) { User.create!(name: 'Pagination User') }
          let(:'X-USER-ID') { current_user.id.to_s }
          let(:limit) { 3 }
          let(:offset) { 0 }

          before do
            # Create multiple followed users with multiple sleep records each
            3.times do |i|
              user = User.create!(name: "Sleeper #{i + 1}")
              current_user.follows.create!(following_user: user)

              # Create 4 sleep records per user (total 12 records)
              4.times do |j|
                user.sleep_records.create!(
                  bedtime: (j + 1).days.ago + 22.hours,
                  wake_time: (j + 1).days.ago + (22 + 8).hours,
                  duration_minutes: 480 + (i * 60) + (j * 15)
                )
              end
            end
          end

          run_test! do |response|
            data = JSON.parse(response.body)

            # Should return only the requested limit
            expect(data['sleep_records'].size).to eq(3)

            # Pagination metadata should be accurate
            expect(data['pagination']['total_count']).to eq(12)
            expect(data['pagination']['current_count']).to eq(3)
            expect(data['pagination']['limit']).to eq(3)
            expect(data['pagination']['offset']).to eq(0)
            expect(data['pagination']['has_more']).to be(true)
            expect(data['pagination']['next_offset']).to eq(3)
            expect(data['pagination']['previous_offset']).to be_nil

            # Statistics should be calculated from full dataset, not just current page
            expect(data['statistics']['total_records']).to eq(12)
            expect(data['statistics']['unique_users']).to eq(3)
          end
        end

        context 'with pagination - second page' do
          let!(:current_user) { User.create!(name: 'Pagination User 2') }
          let(:'X-USER-ID') { current_user.id.to_s }
          let(:limit) { 5 }
          let(:offset) { 5 }

          before do
            # Create 8 sleep records across 2 users
            2.times do |i|
              user = User.create!(name: "Sleeper #{i + 1}")
              current_user.follows.create!(following_user: user)

              4.times do |j|
                user.sleep_records.create!(
                  bedtime: (j + 1).days.ago + 22.hours,
                  wake_time: (j + 1).days.ago + 30.hours,
                  duration_minutes: 480 + (i * 60) + (j * 15)
                )
              end
            end
          end

          run_test! do |response|
            data = JSON.parse(response.body)

            # Should return remaining records (3 out of 8 total)
            expect(data['sleep_records'].size).to eq(3)

            # Pagination metadata for second page
            expect(data['pagination']['total_count']).to eq(8)
            expect(data['pagination']['current_count']).to eq(3)
            expect(data['pagination']['limit']).to eq(5)
            expect(data['pagination']['offset']).to eq(5)
            expect(data['pagination']['has_more']).to be(false)
            expect(data['pagination']['next_offset']).to be_nil
            expect(data['pagination']['previous_offset']).to eq(0)
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

        context 'with invalid sort parameters' do
          let!(:current_user) { User.create!(name: 'Sort Error User') }
          let(:'X-USER-ID') { current_user.id.to_s }

          context 'invalid sort_by parameter' do
            let(:sort_by) { 'invalid_sort' }

            run_test! do |response|
              data = JSON.parse(response.body)
              expect(data['error_code']).to eq('INVALID_SORT_PARAMETER')
              expect(data['error']).to include('Invalid sort parameter')
              expect(data['details']['allowed_values']).to include('duration', 'bedtime', 'wake_time', 'created_at')
            end
          end
        end

        context 'with invalid pagination parameters' do
          let!(:current_user) { User.create!(name: 'Pagination Error User') }
          let(:'X-USER-ID') { current_user.id.to_s }

          context 'limit parameter too large' do
            let(:limit) { 150 }

            run_test! do |response|
              data = JSON.parse(response.body)
              expect(data['error_code']).to eq('INVALID_PAGINATION_LIMIT')
              expect(data['error']).to include('Limit must be between 1 and 100')
            end
          end

          context 'limit parameter too small' do
            let(:limit) { 0 }

            run_test! do |response|
              data = JSON.parse(response.body)
              expect(data['error_code']).to eq('INVALID_PAGINATION_LIMIT')
              expect(data['error']).to include('Limit must be between 1 and 100')
            end
          end

          context 'negative offset parameter' do
            let(:offset) { -5 }

            run_test! do |response|
              data = JSON.parse(response.body)
              expect(data['error_code']).to eq('INVALID_PAGINATION_OFFSET')
              expect(data['error']).to include('Offset must be non-negative')
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