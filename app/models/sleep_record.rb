class SleepRecord < ApplicationRecord
  belongs_to :user

  validates :bedtime, presence: true
  validates :user, presence: true
  validate :bedtime_not_in_future
  validate :wake_time_after_bedtime, if: :wake_time?
  validate :reasonable_duration, if: :completed?
  validate :no_overlapping_sessions, on: :create

  before_save :calculate_duration, if: :will_save_change_to_wake_time?

  scope :completed, -> { where.not(wake_time: nil) }
  scope :active, -> { where(wake_time: nil) }
  scope :for_user, ->(user) { where(user: user) }
  scope :recent_first, -> { order(bedtime: :desc) }

  MAX_REASONABLE_SLEEP_HOURS = 24
  MIN_REASONABLE_SLEEP_MINUTES = 1

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

  def calculate_duration
    if completed?
      self.duration_minutes = ((wake_time - bedtime) / 60).round
    else
      self.duration_minutes = nil
    end
  end

  def reasonable_duration
    return unless completed?

    # Calculate duration for validation
    calculated_duration = ((wake_time - bedtime) / 60).round

    if calculated_duration > (MAX_REASONABLE_SLEEP_HOURS * 60)
      errors.add(:wake_time, "sleep duration cannot exceed #{MAX_REASONABLE_SLEEP_HOURS} hours")
    end

    if calculated_duration < MIN_REASONABLE_SLEEP_MINUTES
      errors.add(:wake_time, "sleep duration must be at least #{MIN_REASONABLE_SLEEP_MINUTES} minute")
    end
  end

  def no_overlapping_sessions
    return unless bedtime && user

    # Check for any overlapping sessions (active sessions or sessions that would overlap)
    # Simplified logic: sessions overlap if existing session starts at/before new bedtime
    # AND existing session is either active (wake_time IS NULL) OR ends after new bedtime
    overlapping = user.sleep_records
                     .where.not(id: id)
                     .where(
                       "bedtime <= ? AND (wake_time IS NULL OR wake_time > ?)",
                       bedtime, bedtime
                     )

    if overlapping.exists?
      errors.add(:bedtime, "overlaps with an existing sleep session")
    end
  end
end
