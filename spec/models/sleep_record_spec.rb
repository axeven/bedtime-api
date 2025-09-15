require 'rails_helper'

RSpec.describe SleepRecord, type: :model do
  let(:user) { create(:user, name: 'Test User') }

  describe 'associations' do
    it 'belongs to user' do
      sleep_record = SleepRecord.new
      expect(sleep_record).to respond_to(:user)
    end

    it 'is invalid without a user' do
      sleep_record = SleepRecord.new(bedtime: Time.current)
      expect(sleep_record).not_to be_valid
      expect(sleep_record.errors[:user]).to include("can't be blank")
    end

    it 'belongs to a specific user' do
      user = create(:user)
      sleep_record = create(:sleep_record, user: user)
      expect(sleep_record.user).to eq(user)
    end
  end

  describe 'validations' do
    describe 'bedtime' do
      it 'is required' do
        sleep_record = SleepRecord.new(user: user)
        expect(sleep_record).not_to be_valid
        expect(sleep_record.errors[:bedtime]).to include("can't be blank")
      end

      it 'cannot be in the future' do
        future_time = 1.hour.from_now
        sleep_record = SleepRecord.new(user: user, bedtime: future_time)
        expect(sleep_record).not_to be_valid
        expect(sleep_record.errors[:bedtime]).to include("cannot be in the future")
      end

      it 'allows current time' do
        current_time = Time.current
        sleep_record = SleepRecord.new(user: user, bedtime: current_time)
        expect(sleep_record).to be_valid
      end

      it 'allows past time' do
        past_time = 1.hour.ago
        sleep_record = SleepRecord.new(user: user, bedtime: past_time)
        expect(sleep_record).to be_valid
      end
    end

    describe 'user' do
      it 'is required' do
        sleep_record = SleepRecord.new(bedtime: Time.current)
        expect(sleep_record).not_to be_valid
        expect(sleep_record.errors[:user]).to include("can't be blank")
      end
    end

    describe 'wake_time' do
      it 'is optional' do
        sleep_record = SleepRecord.new(user: user, bedtime: Time.current)
        expect(sleep_record).to be_valid
      end

      it 'must be after bedtime' do
        bedtime = 2.hours.ago
        wake_time = 3.hours.ago # Before bedtime
        sleep_record = SleepRecord.new(user: user, bedtime: bedtime, wake_time: wake_time)
        expect(sleep_record).not_to be_valid
        expect(sleep_record.errors[:wake_time]).to include("must be after bedtime")
      end

      it 'allows wake_time after bedtime' do
        bedtime = 2.hours.ago
        wake_time = 1.hour.ago # After bedtime
        sleep_record = SleepRecord.new(user: user, bedtime: bedtime, wake_time: wake_time)
        expect(sleep_record).to be_valid
      end
    end
  end

  describe 'scopes' do
    let!(:active_record) { create(:sleep_record, user: user, bedtime: 2.hours.ago, wake_time: nil) }
    let!(:completed_record) { create(:sleep_record, user: user, bedtime: 4.hours.ago, wake_time: 2.hours.ago) }

    describe '.active' do
      it 'returns only active sleep records' do
        expect(SleepRecord.active).to include(active_record)
        expect(SleepRecord.active).not_to include(completed_record)
      end
    end

    describe '.completed' do
      it 'returns only completed sleep records' do
        expect(SleepRecord.completed).to include(completed_record)
        expect(SleepRecord.completed).not_to include(active_record)
      end
    end

    describe 'social feed scopes' do
      let!(:user1) { create(:user, name: 'User 1') }
      let!(:user2) { create(:user, name: 'User 2') }
      let!(:user3) { create(:user, name: 'User 3') }

      # Create various types of records for testing
      let!(:completed_recent_record1) do
        create(:sleep_record,
               user: user1,
               bedtime: 3.days.ago,
               wake_time: 3.days.ago + 8.hours) # 8 hours = 480 minutes
      end

      let!(:completed_recent_record2) do
        create(:sleep_record,
               user: user2,
               bedtime: 1.day.ago,
               wake_time: 1.day.ago + 9.hours) # 9 hours = 540 minutes
      end

      let!(:completed_old_record) do
        create(:sleep_record,
               user: user1,
               bedtime: 10.days.ago,
               wake_time: 10.days.ago + 7.hours) # 7 hours = 420 minutes
      end

      let!(:incomplete_recent_record) do
        create(:sleep_record,
               user: user2,
               bedtime: 1.day.ago + 12.hours,
               wake_time: nil,
               duration_minutes: nil)
      end

      let!(:incomplete_with_bedtime_only) do
        create(:sleep_record,
               user: user3,
               bedtime: 5.days.ago,
               wake_time: nil,
               duration_minutes: nil)
      end

      describe '.completed_records' do
        it 'returns only records with both bedtime and wake_time' do
          results = SleepRecord.completed_records

          expect(results).to include(completed_recent_record1, completed_recent_record2, completed_old_record)
          expect(results).not_to include(incomplete_recent_record, incomplete_with_bedtime_only)
        end

        it 'excludes records with nil wake_time' do
          results = SleepRecord.completed_records

          results.each do |record|
            expect(record.wake_time).not_to be_nil
            expect(record.bedtime).not_to be_nil
          end
        end
      end

      describe '.recent_records' do
        it 'returns records from last 7 days by default' do
          results = SleepRecord.recent_records

          expect(results).to include(completed_recent_record1, completed_recent_record2, incomplete_recent_record)
          expect(results).not_to include(completed_old_record)
        end

        it 'accepts custom day range' do
          results = SleepRecord.recent_records(2)

          expect(results).to include(completed_recent_record2, incomplete_recent_record)
          expect(results).not_to include(completed_recent_record1, completed_old_record)
          # completed_recent_record1 is from 3 days ago, completed_recent_record2 is from 1 day ago
        end

        it 'filters by bedtime date range' do
          results = SleepRecord.recent_records(5)

          results.each do |record|
            expect(record.bedtime).to be >= 5.days.ago
            expect(record.bedtime).to be <= Time.current
          end
        end
      end

      describe '.by_duration' do
        it 'orders records by duration in descending order' do
          results = SleepRecord.completed_records.by_duration

          durations = results.pluck(:duration_minutes).compact
          expect(durations).to eq(durations.sort.reverse)
        end

        it 'puts longest sleep first' do
          results = SleepRecord.completed_records.by_duration

          expect(results.first.duration_minutes).to eq(540) # 9 hours (longest)
        end
      end

      describe '.for_social_feed' do
        it 'combines completed_records, recent_records, and by_duration' do
          results = SleepRecord.for_social_feed

          # Should only include completed recent records
          expect(results).to include(completed_recent_record1, completed_recent_record2)
          expect(results).not_to include(completed_old_record, incomplete_recent_record, incomplete_with_bedtime_only)
        end

        it 'orders by duration descending' do
          results = SleepRecord.for_social_feed
          durations = results.pluck(:duration_minutes).compact

          expect(durations).to eq(durations.sort.reverse)
        end

        it 'only includes records from last 7 days' do
          results = SleepRecord.for_social_feed

          results.each do |record|
            expect(record.bedtime).to be >= 7.days.ago
          end
        end
      end
    end
  end

  describe 'instance methods' do
    describe '#active?' do
      it 'returns true when wake_time is nil' do
        sleep_record = SleepRecord.new(user: user, bedtime: Time.current, wake_time: nil)
        expect(sleep_record.active?).to be true
      end

      it 'returns false when wake_time is present' do
        sleep_record = SleepRecord.new(user: user, bedtime: 2.hours.ago, wake_time: 1.hour.ago)
        expect(sleep_record.active?).to be false
      end
    end

    describe '#completed?' do
      it 'returns true when both bedtime and wake_time are present' do
        sleep_record = SleepRecord.new(user: user, bedtime: 2.hours.ago, wake_time: 1.hour.ago)
        expect(sleep_record.completed?).to be true
      end

      it 'returns false when wake_time is nil' do
        sleep_record = SleepRecord.new(user: user, bedtime: Time.current, wake_time: nil)
        expect(sleep_record.completed?).to be false
      end
    end

    describe '#duration_minutes' do
      it 'returns nil for incomplete sessions' do
        sleep_record = SleepRecord.new(user: user, bedtime: Time.current, wake_time: nil)
        expect(sleep_record.duration_minutes).to be_nil
      end

      it 'calculates duration in minutes for completed sessions' do
        bedtime = Time.parse('2024-01-15 22:00:00')
        wake_time = Time.parse('2024-01-16 06:30:00') # 8.5 hours later
        sleep_record = SleepRecord.new(user: user, bedtime: bedtime, wake_time: wake_time)

        expect(sleep_record.duration_minutes).to eq(510) # 8.5 * 60 = 510 minutes
      end

      it 'handles overnight sleep correctly' do
        bedtime = Time.parse('2024-01-15 23:30:00')
        wake_time = Time.parse('2024-01-16 07:15:00') # 7 hours 45 minutes later
        sleep_record = SleepRecord.new(user: user, bedtime: bedtime, wake_time: wake_time)

        expect(sleep_record.duration_minutes).to eq(465) # 7.75 * 60 = 465 minutes
      end

      it 'handles short naps (under 1 hour)' do
        bedtime = Time.parse('2024-01-15 14:00:00')
        wake_time = Time.parse('2024-01-15 14:30:00') # 30 minutes later
        sleep_record = SleepRecord.new(user: user, bedtime: bedtime, wake_time: wake_time)

        expect(sleep_record.duration_minutes).to eq(30)
      end

      it 'handles long sleep sessions (over 12 hours)' do
        bedtime = Time.parse('2024-01-15 20:00:00')
        wake_time = Time.parse('2024-01-16 10:00:00') # 14 hours later
        sleep_record = SleepRecord.new(user: user, bedtime: bedtime, wake_time: wake_time)

        expect(sleep_record.duration_minutes).to eq(840) # 14 * 60 = 840 minutes
      end

      it 'handles exactly midnight bedtime/wake times' do
        bedtime = Time.parse('2024-01-15 00:00:00')
        wake_time = Time.parse('2024-01-16 00:00:00') # Exactly 24 hours later
        sleep_record = SleepRecord.new(user: user, bedtime: bedtime, wake_time: wake_time)

        expect(sleep_record.duration_minutes).to eq(1440) # 24 * 60 = 1440 minutes
      end
    end
  end

  describe 'business rule validations' do
    describe 'reasonable duration validation' do
      it 'rejects sleep duration over 24 hours' do
        bedtime = Time.parse('2024-01-15 22:00:00')
        wake_time = bedtime + 25.hours # 25 hours later
        sleep_record = SleepRecord.new(user: user, bedtime: bedtime, wake_time: wake_time)

        expect(sleep_record.save).to be false
        expect(sleep_record.errors[:wake_time]).to include("sleep duration cannot exceed 24 hours")
      end

      it 'rejects sleep duration under 1 minute' do
        bedtime = Time.parse('2024-01-15 22:00:00')
        wake_time = bedtime + 10.seconds # 10 seconds later - rounds to 0 minutes
        sleep_record = SleepRecord.new(user: user, bedtime: bedtime, wake_time: wake_time)

        expect(sleep_record.save).to be false
        expect(sleep_record.errors[:wake_time]).to include("sleep duration must be at least 1 minute")
      end

      it 'allows reasonable sleep durations' do
        bedtime = Time.parse('2024-01-15 22:00:00')
        wake_time = bedtime + 8.hours # 8 hours later
        sleep_record = SleepRecord.new(user: user, bedtime: bedtime, wake_time: wake_time)

        expect(sleep_record).to be_valid
      end
    end

    describe 'overlapping sessions validation' do
      it 'prevents creating overlapping sessions' do
        # Create first session: 10 PM - 6 AM
        existing_session = create(:sleep_record,
          user: user,
          bedtime: Time.parse('2024-01-15 22:00:00'),
          wake_time: Time.parse('2024-01-16 06:00:00')
        )

        # Try to create overlapping session: 11 PM - 7 AM (overlaps with existing)
        overlapping_session = SleepRecord.new(
          user: user,
          bedtime: Time.parse('2024-01-15 23:00:00')
        )

        expect(overlapping_session).not_to be_valid
        expect(overlapping_session.errors[:bedtime]).to include("overlaps with an existing sleep session")
      end

      it 'prevents creating session that overlaps with active session' do
        # Create active session starting at 10 PM
        create(:sleep_record, user: user, bedtime: Time.parse('2024-01-15 22:00:00'), wake_time: nil)

        # Try to create session starting at 11 PM (overlaps with active session)
        overlapping_session = SleepRecord.new(
          user: user,
          bedtime: Time.parse('2024-01-15 23:00:00')
        )

        expect(overlapping_session).not_to be_valid
        expect(overlapping_session.errors[:bedtime]).to include("overlaps with an existing sleep session")
      end

      it 'allows non-overlapping sessions' do
        # Create first session: 10 PM - 6 AM
        create(:sleep_record,
          user: user,
          bedtime: Time.parse('2024-01-15 22:00:00'),
          wake_time: Time.parse('2024-01-16 06:00:00')
        )

        # Create non-overlapping session: 7 AM - 3 PM (after first session ends)
        non_overlapping_session = SleepRecord.new(
          user: user,
          bedtime: Time.parse('2024-01-16 07:00:00')
        )

        expect(non_overlapping_session).to be_valid
      end

      it 'allows same user to have sessions on different days' do
        # Create session on day 1
        create(:sleep_record,
          user: user,
          bedtime: Time.parse('2024-01-15 22:00:00'),
          wake_time: Time.parse('2024-01-16 06:00:00')
        )

        # Create session on day 2 (completely separate)
        next_day_session = SleepRecord.new(
          user: user,
          bedtime: Time.parse('2024-01-16 22:00:00')
        )

        expect(next_day_session).to be_valid
      end

      it 'allows different users to have overlapping sessions' do
        other_user = create(:user, name: 'Other User')

        # Create session for first user
        create(:sleep_record,
          user: user,
          bedtime: Time.parse('2024-01-15 22:00:00'),
          wake_time: nil
        )

        # Create overlapping session for different user (should be allowed)
        other_user_session = SleepRecord.new(
          user: other_user,
          bedtime: Time.parse('2024-01-15 23:00:00')
        )

        expect(other_user_session).to be_valid
      end
    end
  end

  describe 'callback tests' do
    describe 'calculate_duration callback' do
      it 'automatically calculates duration on wake_time update' do
        bedtime = 8.hours.ago
        sleep_record = create(:sleep_record, user: user, bedtime: bedtime, wake_time: nil)

        expect(sleep_record.duration_minutes).to be_nil

        wake_time = 2.hours.ago
        sleep_record.update!(wake_time: wake_time)
        sleep_record.reload

        expected_duration = ((wake_time - bedtime) / 60).round
        expect(sleep_record.duration_minutes).to eq(expected_duration)
      end

      it 'updates duration when wake_time changes' do
        bedtime = 8.hours.ago
        initial_wake_time = 4.hours.ago
        sleep_record = create(:sleep_record, user: user, bedtime: bedtime, wake_time: initial_wake_time)

        initial_duration = sleep_record.duration_minutes
        expect(initial_duration).to be > 0

        new_wake_time = 2.hours.ago
        sleep_record.update!(wake_time: new_wake_time)
        sleep_record.reload

        new_duration = sleep_record.duration_minutes
        expect(new_duration).not_to eq(initial_duration)
        expect(new_duration).to eq(((new_wake_time - bedtime) / 60).round)
      end

      it 'sets duration to nil when wake_time is removed' do
        bedtime = 8.hours.ago
        wake_time = 2.hours.ago
        sleep_record = create(:sleep_record, user: user, bedtime: bedtime, wake_time: wake_time)

        expect(sleep_record.duration_minutes).to be > 0

        sleep_record.update!(wake_time: nil)
        sleep_record.reload

        expect(sleep_record.duration_minutes).to be_nil
      end
    end
  end

  describe 'social query helper methods' do
    let!(:current_user) { create(:user, name: 'Current User') }
    let!(:followed_user1) { create(:user, name: 'Followed User 1') }
    let!(:followed_user2) { create(:user, name: 'Followed User 2') }
    let!(:non_followed_user) { create(:user, name: 'Non-Followed User') }

    before do
      # Set up following relationships
      current_user.follows.create!(following_user: followed_user1)
      current_user.follows.create!(following_user: followed_user2)
    end

    describe '.social_feed_for_user' do
      let!(:followed_user1_completed_record) do
        create(:sleep_record,
               user: followed_user1,
               bedtime: 2.days.ago,
               wake_time: 2.days.ago + 8.hours) # 8 hours = 480 minutes
      end

      let!(:followed_user2_completed_record) do
        create(:sleep_record,
               user: followed_user2,
               bedtime: 1.day.ago,
               wake_time: 1.day.ago + 9.hours) # 9 hours = 540 minutes
      end

      let!(:non_followed_user_record) do
        create(:sleep_record,
               user: non_followed_user,
               bedtime: 1.day.ago,
               wake_time: 1.day.ago + 7.hours) # 7 hours = 420 minutes
      end

      let!(:followed_user1_incomplete_record) do
        create(:sleep_record,
               user: followed_user1,
               bedtime: 1.day.ago + 12.hours,
               wake_time: nil,
               duration_minutes: nil)
      end

      let!(:followed_user1_old_record) do
        create(:sleep_record,
               user: followed_user1,
               bedtime: 10.days.ago,
               wake_time: 10.days.ago + 6.hours) # 6 hours = 360 minutes
      end

      it 'returns sleep records only from followed users' do
        results = SleepRecord.social_feed_for_user(current_user)

        expect(results).to include(followed_user1_completed_record, followed_user2_completed_record)
        expect(results).not_to include(non_followed_user_record)
      end

      it 'excludes incomplete records' do
        results = SleepRecord.social_feed_for_user(current_user)

        expect(results).not_to include(followed_user1_incomplete_record)
      end

      it 'excludes old records (outside 7 day range)' do
        results = SleepRecord.social_feed_for_user(current_user)

        expect(results).not_to include(followed_user1_old_record)
      end

      it 'orders by duration descending' do
        results = SleepRecord.social_feed_for_user(current_user)
        durations = results.pluck(:duration_minutes)

        expect(durations).to eq(durations.sort.reverse)
        expect(results.first.duration_minutes).to eq(540) # Longest sleep first
      end

      it 'includes user information via associations' do
        results = SleepRecord.social_feed_for_user(current_user)

        results.each do |record|
          expect(record.user).to be_present
          expect(record.user.name).to be_present
        end
      end

      it 'returns empty collection when user follows no one' do
        lonely_user = create(:user, name: 'Lonely User')
        results = SleepRecord.social_feed_for_user(lonely_user)

        expect(results).to be_empty
      end

      it 'respects privacy boundaries' do
        results = SleepRecord.social_feed_for_user(current_user)

        results.each do |record|
          expect(current_user.following_users).to include(record.user)
        end
      end
    end

    describe '.social_feed_with_pagination' do
      before do
        # Create multiple records for pagination testing
        5.times do |i|
          create(:sleep_record,
                 user: followed_user1,
                 bedtime: (i + 1).days.ago + 22.hours,
                 wake_time: (i + 1).days.ago + 30.hours,
                 duration_minutes: 480 + (i * 60))
        end
      end

      it 'applies limit correctly' do
        results = SleepRecord.social_feed_with_pagination(current_user, limit: 3)

        expect(results.count).to eq(3)
      end

      it 'applies offset correctly' do
        all_results = SleepRecord.social_feed_with_pagination(current_user, limit: 10)
        offset_results = SleepRecord.social_feed_with_pagination(current_user, limit: 3, offset: 2)

        expect(offset_results.first.id).to eq(all_results[2].id)
      end

      it 'maintains ordering with pagination' do
        results = SleepRecord.social_feed_with_pagination(current_user, limit: 3)
        durations = results.pluck(:duration_minutes)

        expect(durations).to eq(durations.sort.reverse)
      end
    end
  end

  describe 'display helper methods' do
    let!(:test_user) { create(:user, name: 'Test Display User') }
    let!(:sleep_record) do
      create(:sleep_record,
             user: test_user,
             bedtime: Time.parse('2024-01-15 22:00:00'),
             wake_time: Time.parse('2024-01-16 04:30:00')) # 6h 30m = 390 minutes
    end

    describe '#user_name' do
      it 'returns the associated user name' do
        expect(sleep_record.user_name).to eq('Test Display User')
      end
    end

    describe '#sleep_date' do
      it 'returns the date portion of bedtime' do
        expect(sleep_record.sleep_date).to eq(Date.parse('2024-01-15'))
      end

      it 'returns nil when bedtime is nil' do
        record = SleepRecord.new(bedtime: nil)
        expect(record.sleep_date).to be_nil
      end
    end

    describe '#formatted_duration' do
      it 'formats duration in hours and minutes' do
        expect(sleep_record.formatted_duration).to eq('6h 30m')
      end

      it 'handles exactly hour durations' do
        sleep_record.update!(wake_time: sleep_record.bedtime + 8.hours) # 8 hours exactly
        sleep_record.reload
        expect(sleep_record.formatted_duration).to eq('8h 0m')
      end

      it 'handles minute-only durations' do
        sleep_record.update!(wake_time: sleep_record.bedtime + 45.minutes) # 45 minutes
        sleep_record.reload
        expect(sleep_record.formatted_duration).to eq('0h 45m')
      end

      it 'returns nil when duration_minutes is nil' do
        sleep_record.update!(wake_time: nil) # This will set duration_minutes to nil
        sleep_record.reload
        expect(sleep_record.formatted_duration).to be_nil
      end
    end
  end
end
