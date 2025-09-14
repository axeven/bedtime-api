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

    describe 'sleep_records' do
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

    describe 'following relationships' do
      let(:user1) { create(:user) }
      let(:user2) { create(:user) }
      let(:user3) { create(:user) }

      it 'has many follows' do
        expect(user1).to respond_to(:follows)
      end

      it 'has many following_users through follows' do
        expect(user1).to respond_to(:following_users)
      end

      it 'has many follower_relationships' do
        expect(user1).to respond_to(:follower_relationships)
      end

      it 'has many followers through follower_relationships' do
        expect(user1).to respond_to(:followers)
      end

      it 'deletes associated follows when user is destroyed' do
        create(:follow, user: user1, following_user: user2)
        expect { user1.destroy }.to change(Follow, :count).by(-1)
      end

      it 'deletes associated follower_relationships when user is destroyed' do
        create(:follow, user: user1, following_user: user2)
        expect { user2.destroy }.to change(Follow, :count).by(-1)
      end

      it 'can follow multiple users' do
        create(:follow, user: user1, following_user: user2)
        create(:follow, user: user1, following_user: user3)

        expect(user1.following_users).to include(user2, user3)
        expect(user1.following_users.count).to eq(2)
      end

      it 'can have multiple followers' do
        create(:follow, user: user1, following_user: user3)
        create(:follow, user: user2, following_user: user3)

        expect(user3.followers).to include(user1, user2)
        expect(user3.followers.count).to eq(2)
      end
    end
  end

  describe 'convenience methods' do
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }
    let(:user3) { create(:user) }

    before do
      create(:follow, user: user1, following_user: user2)
      create(:follow, user: user3, following_user: user1)
    end

    describe '#following?' do
      it 'returns true when user is following another user' do
        expect(user1.following?(user2)).to be true
      end

      it 'returns false when user is not following another user' do
        expect(user1.following?(user3)).to be false
        expect(user2.following?(user1)).to be false
      end
    end

    describe '#followers_count' do
      it 'returns correct count of followers' do
        expect(user1.followers_count).to eq(1)
        expect(user2.followers_count).to eq(1)
        expect(user3.followers_count).to eq(0)
      end
    end

    describe '#following_count' do
      it 'returns correct count of users being followed' do
        expect(user1.following_count).to eq(1)
        expect(user2.following_count).to eq(0)
        expect(user3.following_count).to eq(1)
      end
    end
  end
end
