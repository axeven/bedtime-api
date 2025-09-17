require 'rails_helper'

RSpec.describe 'Social Sleep Data Integration', type: :request do
  # Include authentication helpers
  include AuthenticationHelpers

  before do
    host! 'localhost:3000'
  end

  describe 'Complete social sleep data workflow' do
    let!(:social_user) { User.create!(name: 'Social Network User') }
    let!(:sleeper1) { User.create!(name: 'Early Sleeper') }
    let!(:sleeper2) { User.create!(name: 'Late Sleeper') }
    let!(:sleeper3) { User.create!(name: 'Variable Sleeper') }
    let!(:non_followed_user) { User.create!(name: 'Non-Followed User') }

    before do
      # Setup following relationships
      social_user.follows.create!(following_user: sleeper1)
      social_user.follows.create!(following_user: sleeper2)
      social_user.follows.create!(following_user: sleeper3)

      # Create varied sleep records for comprehensive testing
      create_sleep_records_for_integration_testing
    end

    context 'User follows others and sees their completed sleep records' do
      it 'returns only completed records from followed users' do
        get '/api/v1/following/sleep_records', headers: { 'X-USER-ID' => social_user.id.to_s }

        expect(response).to have_http_status(200)
        data = JSON.parse(response.body)

        # Should only include completed records from followed users
        expect(data['sleep_records'].size).to be > 0
        data['sleep_records'].each do |record|
          expect([ sleeper1.id, sleeper2.id, sleeper3.id ]).to include(record['user_id'])
          expect(record['record_complete']).to be(true)
          expect(record['bedtime']).to be_present
          expect(record['wake_time']).to be_present
          expect(record['duration_minutes']).to be > 0
        end

        # Should not include non-followed user's records
        non_followed_ids = data['sleep_records'].map { |r| r['user_id'] }
        expect(non_followed_ids).not_to include(non_followed_user.id)

        # Should not include social_user's own records
        expect(non_followed_ids).not_to include(social_user.id)
      end
    end

    context 'Date filtering works across multiple users records' do
      it 'filters records correctly by date range' do
        # Test last 3 days
        get '/api/v1/following/sleep_records',
            params: { days: 3 },
            headers: { 'X-USER-ID' => social_user.id.to_s }

        expect(response).to have_http_status(200)
        data = JSON.parse(response.body)

        # Check date range metadata
        expect(data['date_range']['days_back']).to eq(3)
        expect(Date.parse(data['date_range']['from_date'])).to eq(3.days.ago.to_date)
        expect(Date.parse(data['date_range']['to_date'])).to eq(Date.current)

        # All records should be within the date range
        data['sleep_records'].each do |record|
          bedtime = Time.parse(record['bedtime'])
          expect(bedtime).to be >= 3.days.ago
        end
      end

      it 'returns empty for date ranges with no data' do
        # Test with a date range that excludes existing recent records
        # We'll look for records from 10-8 days ago (should be empty)
        # First, let's clear recent records and create an old one
        SleepRecord.where(user: [ sleeper1, sleeper2, sleeper3 ]).destroy_all

        old_record = sleeper1.sleep_records.create!(
          bedtime: 40.days.ago + 22.hours,
          wake_time: 40.days.ago + 30.hours,
          duration_minutes: 480
        )

        get '/api/v1/following/sleep_records',
            params: { days: 7 },  # Only last 7 days (should not include 40-day old record)
            headers: { 'X-USER-ID' => social_user.id.to_s }

        expect(response).to have_http_status(200)
        data = JSON.parse(response.body)

        # Should not include the old record
        expect(data['sleep_records']).to be_empty
        expect(data['pagination']['total_count']).to eq(0)
        expect(data['message']).to include('No completed sleep records found')
      end
    end

    context 'Duration sorting and aggregation across social network' do
      it 'sorts records by duration correctly' do
        get '/api/v1/following/sleep_records',
            params: { sort_by: 'duration' },
            headers: { 'X-USER-ID' => social_user.id.to_s }

        expect(response).to have_http_status(200)
        data = JSON.parse(response.body)

        # Records should be sorted by duration (longest first)
        durations = data['sleep_records'].map { |r| r['duration_minutes'] }
        expect(durations).to eq(durations.sort.reverse)

        # Statistics should reflect actual data
        stats = data['statistics']['duration_stats']
        expect(stats['longest_minutes']).to eq(durations.first)
        expect(stats['shortest_minutes']).to eq(durations.last)
        expect(stats['average_minutes']).to be_between(durations.last, durations.first)
      end

      it 'calculates accurate aggregation statistics' do
        get '/api/v1/following/sleep_records',
            headers: { 'X-USER-ID' => social_user.id.to_s }

        expect(response).to have_http_status(200)
        data = JSON.parse(response.body)

        stats = data['statistics']
        expect(stats['total_records']).to eq(data['sleep_records'].size)
        expect(stats['unique_users']).to eq(3) # sleeper1, sleeper2, sleeper3

        duration_stats = stats['duration_stats']
        expect(duration_stats['total_sleep_hours']).to be > 0
        expect(duration_stats['average_minutes']).to be > 0
        expect(duration_stats['longest_minutes']).to be >= duration_stats['shortest_minutes']
      end
    end

    context 'Pagination across large social sleep datasets' do
      before do
        # Create more records for pagination testing with unique timestamps
        [ sleeper1, sleeper2, sleeper3 ].each_with_index do |user, user_index|
          5.times do |i|
            # Use unique timestamps that don't overlap with existing records
            base_time = (100 + i + user_index * 10).hours.ago
            user.sleep_records.create!(
              bedtime: base_time,
              wake_time: base_time + 8.hours,
              duration_minutes: 480 + (i * 30)
            )
          end
        end
      end

      it 'paginates results correctly' do
        # Test first page
        get '/api/v1/following/sleep_records',
            params: { limit: 5, offset: 0 },
            headers: { 'X-USER-ID' => social_user.id.to_s }

        expect(response).to have_http_status(200)
        data = JSON.parse(response.body)

        expect(data['sleep_records'].size).to eq(5)
        expect(data['pagination']['current_count']).to eq(5)
        expect(data['pagination']['offset']).to eq(0)
        expect(data['pagination']['has_more']).to be(true)
        expect(data['pagination']['next_offset']).to eq(5)

        total_count = data['pagination']['total_count']

        # Test second page
        get '/api/v1/following/sleep_records',
            params: { limit: 5, offset: 5 },
            headers: { 'X-USER-ID' => social_user.id.to_s }

        expect(response).to have_http_status(200)
        data2 = JSON.parse(response.body)

        expect(data2['pagination']['offset']).to eq(5)
        expect(data2['pagination']['previous_offset']).to eq(0)
        expect(data2['pagination']['total_count']).to eq(total_count)

        # Statistics should be the same across pages (calculated from full dataset)
        expect(data2['statistics']['total_records']).to eq(data['statistics']['total_records'])
      end
    end

    context 'Privacy controls prevent unauthorized access' do
      it 'excludes current user own records from social feed' do
        # Create sleep record for social_user themselves with unique timestamp
        social_user.sleep_records.create!(
          bedtime: 200.hours.ago,
          wake_time: 200.hours.ago + 8.hours,
          duration_minutes: 480
        )

        get '/api/v1/following/sleep_records',
            headers: { 'X-USER-ID' => social_user.id.to_s }

        expect(response).to have_http_status(200)
        data = JSON.parse(response.body)

        # Should not include social_user's own record
        user_ids = data['sleep_records'].map { |r| r['user_id'] }
        expect(user_ids).not_to include(social_user.id)

        # Privacy info should reflect this
        expect(data['privacy_info']['your_records_included']).to be(false)
      end

      it 'only includes records from followed users' do
        # Create sleep record for non-followed user with unique timestamp
        non_followed_user.sleep_records.create!(
          bedtime: 6.hours.ago,
          wake_time: 6.hours.ago + 8.hours,
          duration_minutes: 480
        )

        get '/api/v1/following/sleep_records',
            headers: { 'X-USER-ID' => social_user.id.to_s }

        expect(response).to have_http_status(200)
        data = JSON.parse(response.body)

        # Should not include non-followed user's record
        user_ids = data['sleep_records'].map { |r| r['user_id'] }
        expect(user_ids).not_to include(non_followed_user.id)

        # Should only include followed users
        expect(user_ids.uniq.sort).to eq([ sleeper1.id, sleeper2.id, sleeper3.id ].sort)
      end

      it 'excludes incomplete records' do
        # Create incomplete record for followed user with unique timestamp
        incomplete_record = sleeper1.sleep_records.create!(
          bedtime: 300.hours.ago,
          wake_time: nil,
          duration_minutes: nil
        )

        get '/api/v1/following/sleep_records',
            headers: { 'X-USER-ID' => social_user.id.to_s }

        expect(response).to have_http_status(200)
        data = JSON.parse(response.body)

        # Should not include incomplete record
        record_ids = data['sleep_records'].map { |r| r['id'] }
        expect(record_ids).not_to include(incomplete_record.id)

        # All returned records should be complete
        data['sleep_records'].each do |record|
          expect(record['record_complete']).to be(true)
        end
      end
    end
  end

  describe 'Edge cases and error scenarios' do
    context 'Empty social networks' do
      let!(:lonely_user) { User.create!(name: 'Lonely User') }

      it 'handles user with no following relationships' do
        get '/api/v1/following/sleep_records',
            headers: { 'X-USER-ID' => lonely_user.id.to_s }

        expect(response).to have_http_status(200)
        data = JSON.parse(response.body)

        expect(data['sleep_records']).to be_empty
        expect(data['pagination']['total_count']).to eq(0)
        expect(data['privacy_info']['following_count']).to eq(0)
        expect(data['message']).to include("You're not following anyone yet")
      end
    end

    context 'Users with no completed sleep records' do
      let!(:social_user) { User.create!(name: 'Social User No Records') }
      let!(:sleeper_no_complete) { User.create!(name: 'Sleeper No Complete') }

      before do
        social_user.follows.create!(following_user: sleeper_no_complete)

        # Create only incomplete records
        sleeper_no_complete.sleep_records.create!(
          bedtime: 1.day.ago + 22.hours,
          wake_time: nil,
          duration_minutes: nil
        )
      end

      it 'handles followed users with no completed records' do
        get '/api/v1/following/sleep_records',
            headers: { 'X-USER-ID' => social_user.id.to_s }

        expect(response).to have_http_status(200)
        data = JSON.parse(response.body)

        expect(data['sleep_records']).to be_empty
        expect(data['pagination']['total_count']).to eq(0)
        expect(data['privacy_info']['following_count']).to eq(1)
        expect(data['message']).to include('No completed sleep records found from the 1 users you follow')
      end
    end

    context 'Invalid parameters' do
      let!(:user) { User.create!(name: 'Test User') }

      it 'handles invalid date range' do
        get '/api/v1/following/sleep_records',
            params: { days: 50 },
            headers: { 'X-USER-ID' => user.id.to_s }

        expect(response).to have_http_status(400)
        data = JSON.parse(response.body)
        expect(data['error_code']).to eq('INVALID_DATE_RANGE')
      end

      it 'handles invalid sort parameter' do
        get '/api/v1/following/sleep_records',
            params: { sort_by: 'invalid_field' },
            headers: { 'X-USER-ID' => user.id.to_s }

        expect(response).to have_http_status(400)
        data = JSON.parse(response.body)
        expect(data['error_code']).to eq('INVALID_SORT_PARAMETER')
      end

      it 'handles invalid pagination parameters' do
        get '/api/v1/following/sleep_records',
            params: { limit: 200 },
            headers: { 'X-USER-ID' => user.id.to_s }

        expect(response).to have_http_status(400)
        data = JSON.parse(response.body)
        expect(data['error_code']).to eq('INVALID_PAGINATION_LIMIT')
      end
    end

    context 'Authentication and authorization' do
      it 'requires authentication header' do
        get '/api/v1/following/sleep_records'

        expect(response).to have_http_status(400)
        data = JSON.parse(response.body)
        expect(data['error_code']).to eq('MISSING_USER_ID')
      end

      it 'handles invalid user ID' do
        get '/api/v1/following/sleep_records',
            headers: { 'X-USER-ID' => '999999' }

        expect(response).to have_http_status(404)
        data = JSON.parse(response.body)
        expect(data['error_code']).to eq('USER_NOT_FOUND')
      end
    end
  end

  private

  def create_sleep_records_for_integration_testing
    base_time = Time.current

    # Early Sleeper - consistent early bedtime (unique timestamps)
    sleeper1.sleep_records.create!(
      bedtime: base_time - 50.hours,  # ~2 days ago, 22:00
      wake_time: base_time - 42.hours, # ~2 days ago, 06:00
      duration_minutes: 480 # 8 hours
    )
    sleeper1.sleep_records.create!(
      bedtime: base_time - 26.hours,  # ~1 day ago, 22:00
      wake_time: base_time - 19.hours, # ~1 day ago, 05:00
      duration_minutes: 420 # 7 hours
    )

    # Late Sleeper - consistent late bedtime (unique timestamps)
    sleeper2.sleep_records.create!(
      bedtime: base_time - 49.hours,  # ~2 days ago, 23:00
      wake_time: base_time - 40.hours, # ~2 days ago, 08:00
      duration_minutes: 540 # 9 hours
    )
    sleeper2.sleep_records.create!(
      bedtime: base_time - 25.hours,  # ~1 day ago, 23:00
      wake_time: base_time - 17.hours, # ~1 day ago, 07:00
      duration_minutes: 480 # 8 hours
    )

    # Variable Sleeper - mixed schedule (unique timestamps)
    sleeper3.sleep_records.create!(
      bedtime: base_time - 74.hours,  # ~3 days ago, 22:00
      wake_time: base_time - 68.hours, # ~3 days ago, 04:00
      duration_minutes: 360 # 6 hours
    )
    sleeper3.sleep_records.create!(
      bedtime: base_time - 24.hours,  # ~1 day ago, 22:00
      wake_time: base_time - 14.hours, # ~1 day ago, 08:00
      duration_minutes: 600 # 10 hours
    )

    # Non-followed user (should not appear in results) - unique timestamp
    non_followed_user.sleep_records.create!(
      bedtime: base_time - 23.hours,  # ~1 day ago, 23:00
      wake_time: base_time - 15.hours, # ~1 day ago, 07:00
      duration_minutes: 480
    )

    # Create some incomplete records that should be filtered out - unique timestamp
    sleeper1.sleep_records.create!(
      bedtime: base_time - 12.hours,  # ~12 hours ago
      wake_time: nil,
      duration_minutes: nil
    )

    # Create record for social_user (should not appear in their own social feed) - unique timestamp
    social_user.sleep_records.create!(
      bedtime: base_time - 10.hours,  # ~10 hours ago
      wake_time: base_time - 2.hours,  # ~2 hours ago
      duration_minutes: 480
    )
  end
end
