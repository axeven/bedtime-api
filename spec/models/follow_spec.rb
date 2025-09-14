require 'rails_helper'

RSpec.describe Follow, type: :model do
  describe 'validations' do
    let(:user) { create(:user) }
    let(:following_user) { create(:user) }

    it 'is valid with valid attributes' do
      follow = Follow.new(user: user, following_user: following_user)
      expect(follow).to be_valid
    end

    it 'is invalid without a user' do
      follow = Follow.new(following_user: following_user)
      expect(follow).not_to be_valid
      expect(follow.errors[:user]).to include("must exist")
    end

    it 'is invalid without a following_user' do
      follow = Follow.new(user: user)
      expect(follow).not_to be_valid
      expect(follow.errors[:following_user]).to include("must exist")
    end

    it 'prevents self-following' do
      follow = Follow.new(user: user, following_user: user)
      expect(follow).not_to be_valid
      expect(follow.errors[:following_user]).to include("cannot follow yourself")
    end

    it 'prevents duplicate follow relationships' do
      Follow.create!(user: user, following_user: following_user)
      duplicate_follow = Follow.new(user: user, following_user: following_user)
      expect(duplicate_follow).not_to be_valid
      expect(duplicate_follow.errors[:user_id]).to include("has already been taken")
    end

    it 'enforces unique constraint on [user_id, following_user_id]' do
      Follow.create!(user: user, following_user: following_user)
      expect {
        Follow.create!(user: user, following_user: following_user)
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe 'associations' do
    let(:user) { create(:user) }
    let(:following_user) { create(:user) }

    it 'belongs to user (follower)' do
      follow = Follow.new(user: user, following_user: following_user)
      expect(follow.user).to eq(user)
    end

    it 'belongs to following_user (followed user)' do
      follow = Follow.new(user: user, following_user: following_user)
      expect(follow.following_user).to eq(following_user)
    end
  end

  describe 'scopes' do
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }
    let(:user3) { create(:user) }

    before do
      # user1 follows user2 and user3
      create(:follow, user: user1, following_user: user2)
      create(:follow, user: user1, following_user: user3)

      # user2 follows user3
      create(:follow, user: user2, following_user: user3)
    end

    describe '.for_user' do
      it 'returns follows for specific user' do
        follows = Follow.for_user(user1)
        expect(follows.count).to eq(2)
        expect(follows.pluck(:following_user_id)).to contain_exactly(user2.id, user3.id)
      end

      it 'returns empty collection for user with no follows' do
        new_user = create(:user)
        follows = Follow.for_user(new_user)
        expect(follows).to be_empty
      end
    end

    describe '.followers_of' do
      it 'returns followers of specific user' do
        followers = Follow.followers_of(user3)
        expect(followers.count).to eq(2)
        expect(followers.pluck(:user_id)).to contain_exactly(user1.id, user2.id)
      end

      it 'returns empty collection for user with no followers' do
        new_user = create(:user)
        followers = Follow.followers_of(new_user)
        expect(followers).to be_empty
      end
    end
  end
end
