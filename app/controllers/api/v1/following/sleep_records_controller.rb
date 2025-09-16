class Api::V1::Following::SleepRecordsController < Api::V1::BaseController
  before_action :validate_date_params
  before_action :validate_sort_params

  def index
    days_back = params[:days]&.to_i || 7
    sort_by = params[:sort_by] || 'duration'

    sleep_records = SleepRecord.social_feed_for_user(current_user)
                               .recent_records(days_back)
                               .apply_sorting(sort_by)

    # Log access for audit purposes
    log_social_data_access(sleep_records.count)

    if sleep_records.empty?
      render_success({
        sleep_records: [],
        total_count: 0,
        statistics: generate_empty_statistics,
        date_range: date_range_info(days_back),
        sorting: { sort_by: sort_by },
        privacy_info: privacy_info,
        message: determine_empty_message(days_back)
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
        created_at: record.created_at.iso8601,
        record_complete: record.complete_record?
      }
    end

    statistics = generate_statistics(sleep_records)

    render_success({
      sleep_records: records_data,
      total_count: records_data.length,
      statistics: statistics,
      date_range: date_range_info(days_back),
      sorting: { sort_by: sort_by },
      privacy_info: privacy_info
    })
  end

  private

  def log_social_data_access(record_count)
    Rails.logger.info "User #{current_user.id} accessed #{record_count} social sleep records"
  end

  def privacy_info
    {
      data_source: 'followed_users_only',
      record_types: 'completed_records_only',
      your_records_included: false,
      following_count: current_user.following_users.count
    }
  end

  def determine_empty_message(days_back)
    following_count = current_user.following_users.count

    if following_count == 0
      "You're not following anyone yet. Follow users to see their sleep data!"
    else
      "No completed sleep records found from the #{following_count} users you follow in the last #{days_back} days."
    end
  end

  def validate_sort_params
    allowed_sorts = %w[duration bedtime wake_time created_at]
    if params[:sort_by].present? && !allowed_sorts.include?(params[:sort_by])
      render_error(
        'Invalid sort parameter',
        'INVALID_SORT_PARAMETER',
        { allowed_values: allowed_sorts },
        :bad_request
      )
    end
  end

  def generate_statistics(records)
    durations = records.pluck(:duration_minutes).compact
    return generate_empty_statistics if durations.empty?

    {
      total_records: records.count,
      unique_users: records.pluck(:user_id).uniq.count,
      duration_stats: {
        average_minutes: (durations.sum.to_f / durations.count).round,
        longest_minutes: durations.max,
        shortest_minutes: durations.min,
        total_sleep_hours: (durations.sum.to_f / 60).round(1)
      }
    }
  end

  def generate_empty_statistics
    {
      total_records: 0,
      unique_users: 0,
      duration_stats: {
        average_minutes: 0,
        longest_minutes: 0,
        shortest_minutes: 0,
        total_sleep_hours: 0
      }
    }
  end

  def date_range_info(days_back)
    {
      days_back: days_back,
      from_date: days_back.days.ago.to_date.iso8601,
      to_date: Date.current.iso8601
    }
  end

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