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
end
