class Follow < ApplicationRecord
  belongs_to :user
  belongs_to :following_user, class_name: 'User'

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
    # Invalidate follower's following count cache
    Rails.cache.delete("user:#{user_id}:following_count")

    # Invalidate following_user's followers count cache
    Rails.cache.delete("user:#{following_user_id}:followers_count")
  end
end
