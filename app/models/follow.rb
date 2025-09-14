class Follow < ApplicationRecord
  belongs_to :user
  belongs_to :following_user, class_name: 'User'

  validates :user, presence: true
  validates :following_user, presence: true
  validates :user_id, uniqueness: { scope: :following_user_id }
  validate :cannot_follow_self

  scope :for_user, ->(user) { where(user: user) }
  scope :followers_of, ->(user) { where(following_user: user) }

  private

  def cannot_follow_self
    errors.add(:following_user, "cannot follow yourself") if user_id == following_user_id
  end
end
