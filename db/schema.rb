# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_09_15_040837) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "follows", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "following_user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["following_user_id"], name: "index_follows_on_following_user_id"
    t.index ["user_id", "following_user_id"], name: "index_follows_on_user_id_and_following_user_id", unique: true
    t.index ["user_id"], name: "index_follows_on_user_id"
  end

  create_table "sleep_records", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.datetime "bedtime", null: false
    t.datetime "wake_time"
    t.integer "duration_minutes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bedtime", "wake_time"], name: "index_sleep_records_on_completion_and_date"
    t.index ["bedtime"], name: "index_sleep_records_on_bedtime"
    t.index ["duration_minutes"], name: "index_sleep_records_on_duration"
    t.index ["user_id", "bedtime", "wake_time", "duration_minutes"], name: "index_sleep_records_social_feed"
    t.index ["user_id", "bedtime"], name: "index_sleep_records_on_user_and_bedtime"
    t.index ["user_id", "bedtime"], name: "index_sleep_records_on_user_id_and_bedtime"
    t.index ["user_id"], name: "index_sleep_records_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "follows", "users"
  add_foreign_key "follows", "users", column: "following_user_id"
  add_foreign_key "sleep_records", "users"
end
