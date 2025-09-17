class User < ApplicationRecord
  validates :name, presence: true, length: { minimum: 1, maximum: 100 }

  has_many :sleep_records, dependent: :destroy

  # Cache warming after user creation
  after_create :warm_user_cache

  # Following relationships
  has_many :follows, dependent: :destroy
  has_many :following_users, through: :follows, source: :following_user

  # Follower relationships (reverse)
  has_many :follower_relationships, class_name: 'Follow', foreign_key: 'following_user_id', dependent: :destroy
  has_many :followers, through: :follower_relationships, source: :user

  # Convenience methods with optimized queries
  def following?(user)
    follows.exists?(following_user: user)
  end

  def followers_count
    # Cache this value since it's frequently accessed
    Rails.cache.fetch(CacheService.cache_key(:followers_count, id), expires_in: CacheService::EXPIRATION_TIMES[:followers_count]) do
      follower_relationships.count
    end
  end

  def following_count
    # Cache this value since it's frequently accessed
    Rails.cache.fetch(CacheService.cache_key(:following_count, id), expires_in: CacheService::EXPIRATION_TIMES[:following_count]) do
      follows.count
    end
  end

  private

  def warm_user_cache
    # Warm cache immediately in development, async in production
    if Rails.env.production?
      CacheWarmupJob.perform_later(id)
    else
      CacheService.warm_user_cache(self)
    end
  rescue => e
    Rails.logger.error "Cache warmup failed for user #{id}: #{e.message}"
  end

end
