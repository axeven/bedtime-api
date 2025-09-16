class OptimizeActiveSessionIndexFinal < ActiveRecord::Migration[8.0]
  def up
    # FINAL ACTIVE SESSION INDEX OPTIMIZATION
    # Your optimization: [user_id, bedtime] → [user_id] WHERE wake_time IS NULL
    # Rationale: Only 1 active session per user, bedtime column unnecessary

    puts "Applying final active session index optimization..."
    puts ""

    remove_index :sleep_records, name: 'idx_sleep_records_active'

    add_index :sleep_records, :user_id,
              name: 'idx_sleep_records_active',
              where: 'wake_time IS NULL'

    puts "✅ Active session index optimized!"
    puts ""
    puts "Changed: [user_id, bedtime] WHERE wake_time IS NULL"
    puts "To:      [user_id] WHERE wake_time IS NULL"
    puts ""
    puts "Benefits:"
    puts "• Smaller index size (removed unnecessary bedtime column)"
    puts "• Faster lookups (simpler index structure)"
    puts "• Business logic match: Only 1 active session per user"
    puts "• Query pattern: current_user.sleep_records.active.first"
  end

  def down
    remove_index :sleep_records, name: 'idx_sleep_records_active'
    add_index :sleep_records, [:user_id, :bedtime],
              name: 'idx_sleep_records_active',
              where: 'wake_time IS NULL'
  end
end