class Api::V1::Following::SleepRecordsController < Api::V1::BaseController
  before_action :validate_date_params

  def index
    days_back = params[:days]&.to_i || 7

    sleep_records = SleepRecord.social_feed_for_user(current_user)
                               .recent_records(days_back)

    if sleep_records.empty?
      render_success({
        sleep_records: [],
        total_count: 0,
        date_range: {
          days_back: days_back,
          from_date: days_back.days.ago.to_date.iso8601,
          to_date: Date.current.iso8601
        },
        message: "No sleep records found in the last #{days_back} days. Follow users to see their sleep data!"
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
      total_count: records_data.length,
      date_range: {
        days_back: days_back,
        from_date: days_back.days.ago.to_date.iso8601,
        to_date: Date.current.iso8601
      }
    })
  end

  private

  def validate_date_params
    if params[:days].present?
      days = params[:days].to_i
      if days < 1 || days > 30
        render_error(
          'Date range must be between 1 and 30 days',
          'INVALID_DATE_RANGE',
          { allowed_range: '1-30 days' },
          :bad_request
        )
        return
      end
    end
  end
end