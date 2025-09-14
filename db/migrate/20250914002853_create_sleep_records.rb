class CreateSleepRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :sleep_records do |t|
      t.references :user, null: false, foreign_key: true
      t.datetime :bedtime, null: false
      t.datetime :wake_time, null: true
      t.integer :duration_minutes, null: true

      t.timestamps
    end

    add_index :sleep_records, :bedtime
    add_index :sleep_records, [ :user_id, :bedtime ]
  end
end
