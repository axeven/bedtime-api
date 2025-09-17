class OptimizeActiveSessionIndexFinal < ActiveRecord::Migration[8.0]
  def up
    # FINAL ACTIVE SESSION INDEX OPTIMIZATION
    # Your optimization: [user_id, bedtime] → [user_id] WHERE wake_time IS NULL
    # Rationale: Only 1 active session per user, bedtime column unnecessary

    remove_index :sleep_records, name: 'idx_sleep_records_active'

    add_index :sleep_records, :user_id,
              name: 'idx_sleep_records_active',
              where: 'wake_time IS NULL'
  end

  def down
    remove_index :sleep_records, name: 'idx_sleep_records_active'
    add_index :sleep_records, [ :user_id, :bedtime ],
              name: 'idx_sleep_records_active',
              where: 'wake_time IS NULL'
  end
end
