class Api::V1::Following::SleepRecordsController < Api::V1::BaseController
  before_action :validate_date_params
  before_action :validate_sort_params
  before_action :validate_pagination_params

  def index
    days_back = params[:days]&.to_i || 7
    sort_by = params[:sort_by] || 'duration'
    limit = [params[:limit]&.to_i || 20, 100].min
    offset = params[:offset]&.to_i || 0

    # Base query with performance optimizations
    base_query = SleepRecord.social_feed_for_user(current_user)
                           .recent_records(days_back)
                           .apply_sorting(sort_by)

    # Get total count efficiently
    total_count = base_query.count

    # Get paginated results (N+1 prevention already handled in social_feed_for_user)
    sleep_records = base_query.limit(limit)
                             .offset(offset)

    # Log access for audit purposes
    log_social_data_access(sleep_records.length, total_count)

    if sleep_records.empty?
      render_success({
        sleep_records: [],
        pagination: pagination_info(0, limit, offset, total_count),
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
        user_name: record.user_name, # No N+1 due to includes
        bedtime: record.bedtime.iso8601,
        wake_time: record.wake_time.iso8601,
        duration_minutes: record.duration_minutes,
        formatted_duration: record.formatted_duration,
        sleep_date: record.sleep_date.iso8601,
        created_at: record.created_at.iso8601,
        record_complete: record.complete_record?
      }
    end

    # Generate statistics from full dataset, not just current page
    statistics = generate_statistics_from_base_query(base_query)

    render_success({
      sleep_records: records_data,
      pagination: pagination_info(records_data.length, limit, offset, total_count),
      statistics: statistics,
      date_range: date_range_info(days_back),
      sorting: { sort_by: sort_by },
      privacy_info: privacy_info
    })
  end

  private

  def log_social_data_access(returned_count, total_available)
    Rails.logger.info "User #{current_user.id} accessed #{returned_count}/#{total_available} social sleep records"
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

  def validate_pagination_params
    if params[:limit].present?
      limit = params[:limit].to_i
      if limit < 1 || limit > 100
        render_error(
          'Limit must be between 1 and 100',
          'INVALID_PAGINATION_LIMIT',
          { allowed_range: '1-100' },
          :bad_request
        )
        return
      end
    end

    if params[:offset].present?
      offset = params[:offset].to_i
      if offset < 0
        render_error(
          'Offset must be non-negative',
          'INVALID_PAGINATION_OFFSET',
          {},
          :bad_request
        )
        return
      end
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

  def pagination_info(current_count, limit, offset, total_count)
    {
      total_count: total_count,
      current_count: current_count,
      limit: limit,
      offset: offset,
      has_more: (offset + limit) < total_count,
      next_offset: (offset + limit) < total_count ? (offset + limit) : nil,
      previous_offset: offset > 0 ? [offset - limit, 0].max : nil
    }
  end

  def generate_statistics_from_base_query(base_query)
    # Use database aggregation for efficiency
    durations = base_query.pluck(:duration_minutes).compact

    return generate_empty_statistics if durations.empty?

    {
      total_records: durations.count,
      unique_users: base_query.distinct.count(:user_id),
      duration_stats: {
        average_minutes: (durations.sum.to_f / durations.count).round,
        longest_minutes: durations.max,
        shortest_minutes: durations.min,
        total_sleep_hours: (durations.sum.to_f / 60).round(1)
      }
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