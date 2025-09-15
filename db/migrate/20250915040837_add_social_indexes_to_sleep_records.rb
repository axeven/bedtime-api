class AddSocialIndexesToSleepRecords < ActiveRecord::Migration[8.0]
  def change
    # Composite index for social queries (user + date range)
    add_index :sleep_records, [:user_id, :bedtime], name: 'index_sleep_records_on_user_and_bedtime'

    # Index for duration sorting
    add_index :sleep_records, :duration_minutes, name: 'index_sleep_records_on_duration'

    # Composite index for completed records in date range
    add_index :sleep_records, [:bedtime, :wake_time], name: 'index_sleep_records_on_completion_and_date'

    # Index for efficient social feed queries
    add_index :sleep_records, [:user_id, :bedtime, :wake_time, :duration_minutes],
              name: 'index_sleep_records_social_feed'
  end
end
