class User < ApplicationRecord
  validates :name, presence: true, length: { minimum: 1, maximum: 100 }

  has_many :sleep_records, dependent: :destroy

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
    Rails.cache.fetch("user:#{id}:followers_count", expires_in: 5.minutes) do
      follower_relationships.count
    end
  end

  def following_count
    # Cache this value since it's frequently accessed
    Rails.cache.fetch("user:#{id}:following_count", expires_in: 5.minutes) do
      follows.count
    end
  end

end
