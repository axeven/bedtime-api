class Follow < ApplicationRecord
  belongs_to :user
  belongs_to :following_user, class_name: "User"

  validates :user, presence: true
  validates :following_user, presence: true
  validates :user_id, uniqueness: { scope: :following_user_id }
  validate :cannot_follow_self

  scope :for_user, ->(user) { where(user: user) }
  scope :followers_of, ->(user) { where(following_user: user) }

  # Cache invalidation callbacks
  after_create :invalidate_follow_caches
  after_destroy :invalidate_follow_caches

  private

  def cannot_follow_self
    errors.add(:following_user, "cannot follow yourself") if user_id == following_user_id
  end

  def invalidate_follow_caches
    # Invalidate User model count caches
    Rails.cache.delete(CacheService.cache_key(:following_count, user_id))
    Rails.cache.delete(CacheService.cache_key(:followers_count, following_user_id))

    # Invalidate CacheService list patterns (only small result sets are cached)
    CacheService.delete_user_pattern(:following_list, user_id)
    CacheService.delete_user_pattern(:followers_list, following_user_id)
    CacheService.delete_user_pattern(:social_sleep_stats, user_id)
    CacheService.delete_user_pattern(:sleep_statistics, user_id)
  end
end
