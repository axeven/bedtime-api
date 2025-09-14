class SleepRecord < ApplicationRecord
  belongs_to :user

  validates :bedtime, presence: true
  validates :user, presence: true
  validate :bedtime_not_in_future
  validate :wake_time_after_bedtime, if: :wake_time?

  scope :completed, -> { where.not(wake_time: nil) }
  scope :active, -> { where(wake_time: nil) }
  scope :for_user, ->(user) { where(user: user) }
  scope :recent_first, -> { order(bedtime: :desc) }

  def active?
    wake_time.nil?
  end

  def completed?
    bedtime.present? && wake_time.present?
  end

  def duration_minutes
    return nil unless completed?
    ((wake_time - bedtime) / 60).round
  end

  private

  def bedtime_not_in_future
    return unless bedtime
    errors.add(:bedtime, "cannot be in the future") if bedtime > Time.current
  end

  def wake_time_after_bedtime
    return unless bedtime && wake_time
    errors.add(:wake_time, "must be after bedtime") if wake_time <= bedtime
  end
end