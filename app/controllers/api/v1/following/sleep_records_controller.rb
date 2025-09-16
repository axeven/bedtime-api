class Api::V1::Following::SleepRecordsController < Api::V1::BaseController

  def index
    sleep_records = SleepRecord.social_feed_for_user(current_user)

    if sleep_records.empty?
      render_success({
        sleep_records: [],
        total_count: 0,
        message: "No sleep records found. Follow users to see their sleep data!"
      })
      return
    end

    records_data = sleep_records.map do |record|
      {
        id: record.id,
        user_id: record.user_id,
        user_name: record.user_name,
        bedtime: record.bedtime.iso8601,
        wake_time: record.wake_time.iso8601,
        duration_minutes: record.duration_minutes,
        formatted_duration: record.formatted_duration,
        sleep_date: record.sleep_date.iso8601,
        created_at: record.created_at.iso8601
      }
    end

    render_success({
      sleep_records: records_data,
      total_count: records_data.length
    })
  end
end