class OptimizeDatabaseIndexesComprehensive < ActiveRecord::Migration[8.0]
  def up
    remove_index :sleep_records, name: 'index_sleep_records_on_user_and_bedtime'
    remove_index :sleep_records, name: 'index_sleep_records_on_duration'
    remove_index :sleep_records, name: 'index_sleep_records_on_completion_and_date'
    remove_index :sleep_records, name: 'index_sleep_records_social_feed'

    add_index :users, :name, name: 'idx_users_name'
    add_index :sleep_records, :bedtime, name: 'idx_sleep_records_bedtime'
    add_index :sleep_records, [ :user_id, :bedtime ], name: 'idx_sleep_records_user_bedtime'
    add_index :sleep_records, :user_id, name: 'idx_sleep_records_active', where: 'wake_time IS NULL'
    add_index :sleep_records, [ :user_id, :bedtime ], name: 'idx_sleep_records_user_completed', where: 'wake_time IS NOT NULL'
    add_index :follows, [ :user_id, :created_at ], name: 'idx_follows_user_created'
    add_index :follows, [ :following_user_id, :created_at ], name: 'idx_follows_following_created'
  end

  def down
    remove_index :users, name: 'idx_users_name'
    remove_index :sleep_records, name: 'idx_sleep_records_bedtime'
    remove_index :sleep_records, name: 'idx_sleep_records_user_bedtime'
    remove_index :sleep_records, name: 'idx_sleep_records_active'
    remove_index :sleep_records, name: 'idx_sleep_records_user_completed'
    remove_index :follows, name: 'idx_follows_user_created'
    remove_index :follows, name: 'idx_follows_following_created'

    add_index :sleep_records, [ :user_id, :bedtime ], name: 'index_sleep_records_on_user_and_bedtime'
    add_index :sleep_records, :duration_minutes, name: 'index_sleep_records_on_duration'
    add_index :sleep_records, [ :bedtime, :wake_time ], name: 'index_sleep_records_on_completion_and_date'
    add_index :sleep_records, [ :user_id, :bedtime, :wake_time, :duration_minutes ], name: 'index_sleep_records_social_feed'
  end

  private

  def index_name_exists?(table_name, index_name)
    ActiveRecord::Base.connection.index_name_exists?(table_name, index_name)
  end
end
