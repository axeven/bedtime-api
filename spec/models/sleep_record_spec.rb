require 'rails_helper'

RSpec.describe SleepRecord, type: :model do
  let(:user) { create(:user, name: 'Test User') }

  describe 'associations' do
    it 'belongs to user' do
      sleep_record = SleepRecord.new
      expect(sleep_record).to respond_to(:user)
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
    end
  end
end
