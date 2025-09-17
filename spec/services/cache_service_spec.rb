require 'rails_helper'

RSpec.describe CacheService, type: :service do
  let(:user) { create(:user) }

  before(:each) do
    Rails.cache.clear
  end

  describe '.fetch' do
    it 'caches and retrieves data correctly' do
      key = 'test_key'
      data = { test: 'data' }

      # First call should execute block
      result = CacheService.fetch(key, expires_in: 1.minute) { data }
      expect(result).to eq(data)

      # Second call should return cached data
      cached_result = CacheService.fetch(key, expires_in: 1.minute) { { different: 'data' } }
      expect(cached_result).to eq(data)
    end

    it 'respects expiration time' do
      key = 'expiring_key'
      data = { test: 'data' }

      # Cache with short expiration
      result = CacheService.fetch(key, expires_in: 0.1.seconds) { data }
      expect(result).to eq(data)

      # Wait for expiration and verify new data is fetched
      sleep(0.2)
      new_data = { new: 'data' }
      expired_result = CacheService.fetch(key, expires_in: 1.minute) { new_data }
      expect(expired_result).to eq(new_data)
    end
  end

  describe '.delete' do
    it 'deletes cache keys' do
      key = 'deletable_key'
      CacheService.fetch(key) { 'test_data' }
      expect(Rails.cache.exist?(key)).to be_truthy

      CacheService.delete(key)
      expect(Rails.cache.exist?(key)).to be_falsey
    end
  end

  describe '.delete_pattern' do
    it 'deletes keys matching pattern' do
      CacheService.fetch("following_list:user:#{user.id}:20_0") { [] }
      CacheService.fetch("following_list:user:#{user.id}:40_0") { [] }
      CacheService.fetch("followers_list:user:#{user.id}:20_0") { [] }

      # Verify keys exist
      expect(Rails.cache.exist?("following_list:user:#{user.id}:20_0")).to be_truthy
      expect(Rails.cache.exist?("following_list:user:#{user.id}:40_0")).to be_truthy
      expect(Rails.cache.exist?("followers_list:user:#{user.id}:20_0")).to be_truthy

      # Delete following_list pattern
      CacheService.delete_pattern("following_list:user:#{user.id}:*")

      # Verify following_list keys are deleted but followers_list remains
      expect(Rails.cache.exist?("following_list:user:#{user.id}:20_0")).to be_falsey
      expect(Rails.cache.exist?("following_list:user:#{user.id}:40_0")).to be_falsey
      expect(Rails.cache.exist?("followers_list:user:#{user.id}:20_0")).to be_truthy
    end
  end

  describe '.cache_key' do
    it 'generates consistent cache keys' do
      key1 = CacheService.cache_key('following_list', user.id, '20_0')
      key2 = CacheService.cache_key('following_list', user.id, '20_0')
      expect(key1).to eq(key2)
      expect(key1).to eq("following_list:user:#{user.id}:20_0")
    end

    it 'generates keys without suffix' do
      key = CacheService.cache_key('followers_list', user.id)
      expect(key).to eq("followers_list:user:#{user.id}")
    end
  end

  describe '.warm_user_cache' do
    let(:following_user) { create(:user) }
    let!(:follow) { create(:follow, user: user, following_user: following_user) }
    let!(:sleep_record) { create(:sleep_record, :completed, user: user) }

    it 'warms all cache types for user' do
      expect(Rails.cache.exist?("following_list:user:#{user.id}")).to be_falsey
      expect(Rails.cache.exist?("followers_list:user:#{user.id}")).to be_falsey
      expect(Rails.cache.exist?("sleep_statistics:user:#{user.id}:7_days")).to be_falsey

      CacheService.warm_user_cache(user)

      expect(Rails.cache.exist?("following_list:user:#{user.id}")).to be_truthy
      expect(Rails.cache.exist?("followers_list:user:#{user.id}")).to be_truthy
      expect(Rails.cache.exist?("sleep_statistics:user:#{user.id}:7_days")).to be_truthy
    end

    it 'caches following list data correctly' do
      CacheService.warm_user_cache(user)

      cached_data = Rails.cache.read("following_list:user:#{user.id}")
      expect(cached_data).to be_an(Array)
      expect(cached_data.length).to eq(1)
      expect(cached_data.first[:id]).to eq(following_user.id)
      expect(cached_data.first[:name]).to eq(following_user.name)
    end

    it 'caches sleep statistics correctly' do
      CacheService.warm_user_cache(user)

      cached_stats = Rails.cache.read("sleep_statistics:user:#{user.id}:7_days")
      expect(cached_stats).to be_a(Hash)
      expect(cached_stats[:total_records]).to eq(1)
      expect(cached_stats[:average_duration]).to be_a(Float)
      expect(cached_stats[:total_sleep_time]).to be_a(Integer)
    end
  end

  describe '.cache_stats' do
    it 'returns cache statistics' do
      stats = CacheService.cache_stats

      expect(stats).to be_a(Hash)
      expect(stats).to have_key(:connected_clients)
      expect(stats).to have_key(:used_memory)
      expect(stats).to have_key(:hit_rate)
      expect(stats[:hit_rate]).to be_a(Float)
    end

    it 'handles Redis connection errors gracefully' do
      allow(Rails.cache.redis).to receive(:with).and_raise(Redis::ConnectionError.new("Connection failed"))

      stats = CacheService.cache_stats
      expect(stats).to have_key(:error)
    end
  end

  describe 'expiration times' do
    it 'defines appropriate expiration times for different cache types' do
      expect(CacheService::EXPIRATION_TIMES[:following_list]).to eq(1.hour)
      expect(CacheService::EXPIRATION_TIMES[:followers_list]).to eq(1.hour)
      expect(CacheService::EXPIRATION_TIMES[:following_count]).to eq(1.minutes)
      expect(CacheService::EXPIRATION_TIMES[:followers_count]).to eq(1.minutes)
      expect(CacheService::EXPIRATION_TIMES[:sleep_statistics]).to eq(30.minutes)
      expect(CacheService::EXPIRATION_TIMES[:social_sleep_records]).to eq(5.minutes)
    end
  end
end
