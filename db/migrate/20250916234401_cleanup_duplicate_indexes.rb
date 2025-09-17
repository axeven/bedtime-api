class CleanupDuplicateIndexes < ActiveRecord::Migration[8.0]
  def up
    # Remove all the old/duplicate indexes, keeping only the optimized ones

    # Sleep Records - Remove old indexes that are duplicates or replaced
    remove_index :sleep_records, name: 'index_sleep_records_on_bedtime' if index_exists?(:sleep_records, :bedtime, name: 'index_sleep_records_on_bedtime')
    remove_index :sleep_records, name: 'index_sleep_records_on_user_id_and_bedtime' if index_exists?(:sleep_records, [ :user_id, :bedtime ], name: 'index_sleep_records_on_user_id_and_bedtime')
    remove_index :sleep_records, name: 'index_sleep_records_on_user_id' if index_exists?(:sleep_records, :user_id, name: 'index_sleep_records_on_user_id')

    # Remove social indexes that were replaced by optimized versions
    remove_index :sleep_records, name: 'idx_sleep_records_date_range_completed' if index_exists?(:sleep_records, [ :bedtime, :wake_time ], name: 'idx_sleep_records_date_range_completed')
    remove_index :sleep_records, name: 'idx_sleep_records_created_user' if index_exists?(:sleep_records, [ :created_at, :user_id ], name: 'idx_sleep_records_created_user')
    remove_index :sleep_records, name: 'idx_sleep_records_social_query' if index_exists?(:sleep_records, [ :user_id, :bedtime, :duration_minutes ], name: 'idx_sleep_records_social_query')
    remove_index :sleep_records, name: 'idx_sleep_records_user_wake_time' if index_exists?(:sleep_records, [ :user_id, :wake_time ], name: 'idx_sleep_records_user_wake_time')

    # Follows - Remove old indexes that are duplicates
    remove_index :follows, name: 'index_follows_on_user_id' if index_exists?(:follows, :user_id, name: 'index_follows_on_user_id')
    remove_index :follows, name: 'index_follows_on_following_user_id' if index_exists?(:follows, :following_user_id, name: 'index_follows_on_following_user_id')
    remove_index :follows, name: 'idx_follows_created_user' if index_exists?(:follows, [ :created_at, :user_id ], name: 'idx_follows_created_user')

    puts "Cleaned up duplicate indexes. Final optimized indexes:"
    puts "Users: idx_users_name"
    puts "Sleep Records: idx_sleep_records_bedtime, idx_sleep_records_user_bedtime, idx_sleep_records_active, idx_sleep_records_user_completed"
    puts "Follows: idx_follows_user_created, idx_follows_following_created, index_follows_on_user_id_and_following_user_id (unique)"
  end

  def down
    # This is a cleanup migration - we don't want to restore the duplicate indexes
    puts "This cleanup migration cannot be reversed safely. Please restore from clean migrations if needed."
  end
end
