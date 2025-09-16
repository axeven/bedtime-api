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

  # Optimized scopes for better performance
  scope :with_duration, -> { completed.where.not(duration_minutes: nil) }
  scope :recent_completed, -> { completed.where(bedtime: 7.days.ago..Time.current) }
  scope :long_sleeps, -> { completed.where('duration_minutes >= ?', 480) } # 8+ hours
  scope :short_sleeps, -> { completed.where('duration_minutes <= ?', 300) } # 5- hours

  # Social feed scopes for retrieving sleep data from followed users
  scope :completed_records, -> {
    where.not(bedtime: nil)
         .where.not(wake_time: nil)
         .where.not(duration_minutes: nil)
  }
  scope :recent_records, ->(days = 7) { where(bedtime: days.days.ago..Time.current) }
  scope :by_duration, -> { order(duration_minutes: :desc) }
  scope :for_social_feed, -> { completed_records.recent_records }

  # Flexible sorting scope for social feed
  scope :apply_sorting, ->(sort_by) {
    case sort_by
    when 'duration'
      order(duration_minutes: :desc)
    when 'bedtime'
      order(bedtime: :desc)
    when 'wake_time'
      order(wake_time: :desc)
    when 'created_at'
      order(created_at: :desc)
    else
      order(duration_minutes: :desc) # Default
    end
  }

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

  # Social feed query methods for retrieving sleep records from followed users
  def self.social_feed_for_user(user)
    # Single optimized query with joins to eliminate N+1
    joins(user: :follower_relationships)
      .where(follows: { user_id: user.id })
      .where.not(wake_time: nil)
      .includes(:user)
      .select('sleep_records.*, users.name as user_name')
  end

  def self.social_feed_with_pagination(user, limit: 20, offset: 0)
    social_feed_for_user(user)
      .limit(limit)
      .offset(offset)
  end

  # Display helper methods for formatting sleep record data
  def user_name
    user.name
  end

  def sleep_date
    bedtime&.to_date
  end

  def formatted_duration
    return nil unless duration_minutes
    hours = duration_minutes / 60
    minutes = duration_minutes % 60
    "#{hours}h #{minutes}m"
  end

  # Privacy and validation helpers
  def complete_record?
    bedtime.present? && wake_time.present? && duration_minutes.present?
  end

  def accessible_by?(requesting_user)
    return true if user_id == requesting_user.id
    requesting_user.following?(user)
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
    overlapping_scope = user.sleep_records
    overlapping_scope = overlapping_scope.where.not(id: id) if persisted?

    overlapping = overlapping_scope.where(
      "bedtime <= ? AND (wake_time IS NULL OR wake_time > ?)",
      bedtime, bedtime
    )

    if overlapping.exists?
      errors.add(:bedtime, "overlaps with an existing sleep session")
    end
  end
end
