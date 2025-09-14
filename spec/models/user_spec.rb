require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it 'is valid with a name' do
      user = User.new(name: 'Test User')
      expect(user).to be_valid
    end

    it 'is invalid without a name' do
      user = User.new(name: nil)
      expect(user).not_to be_valid
      expect(user.errors[:name]).to include("can't be blank")
    end

    it 'is invalid with a name that is too long' do
      long_name = 'a' * 101
      user = User.new(name: long_name)
      expect(user).not_to be_valid
      expect(user.errors[:name]).to include("is too long (maximum is 100 characters)")
    end

    it 'is invalid with an empty name' do
      user = User.new(name: '')
      expect(user).not_to be_valid
      expect(user.errors[:name]).to include("is too short (minimum is 1 character)")
    end
  end

  describe 'associations' do
    let(:user) { create(:user) }

    it 'has many sleep_records' do
      expect(user).to respond_to(:sleep_records)
    end

    it 'deletes associated sleep_records when user is destroyed' do
      sleep_record = create(:sleep_record, user: user)
      expect { user.destroy }.to change(SleepRecord, :count).by(-1)
    end

    it 'can have multiple sleep_records' do
      sleep_record1 = create(:sleep_record, user: user, bedtime: 2.days.ago, wake_time: 2.days.ago + 8.hours)
      sleep_record2 = create(:sleep_record, user: user, bedtime: 1.day.ago)

      expect(user.sleep_records).to include(sleep_record1, sleep_record2)
      expect(user.sleep_records.count).to eq(2)
    end
  end
end