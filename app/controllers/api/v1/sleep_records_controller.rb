class Api::V1::SleepRecordsController < Api::V1::BaseController
  before_action :authenticate_user
  before_action :set_sleep_record, only: [ :show, :update, :destroy ]

  def create
    # Check for existing active session
    existing_active = current_user.sleep_records.active.first

    if existing_active
      render_error(
        "You already have an active sleep session",
        "ACTIVE_SESSION_EXISTS",
        { active_session_id: existing_active.id },
        :unprocessable_entity
      )
      return
    end

    sleep_record = current_user.sleep_records.build(sleep_record_params)

    if sleep_record.save
      render_success({
        id: sleep_record.id,
        user_id: sleep_record.user_id,
        bedtime: sleep_record.bedtime.iso8601,
        wake_time: sleep_record.wake_time,
        duration_minutes: sleep_record.duration_minutes,
        active: sleep_record.active?,
        created_at: sleep_record.created_at.iso8601,
        updated_at: sleep_record.updated_at.iso8601
      }, :created)
    else
      render_validation_error(sleep_record)
    end
  end

  def show
    render_success({
      id: @sleep_record.id,
      user_id: @sleep_record.user_id,
      bedtime: @sleep_record.bedtime.iso8601,
      wake_time: @sleep_record.wake_time,
      duration_minutes: @sleep_record.duration_minutes,
      active: @sleep_record.active?,
      created_at: @sleep_record.created_at.iso8601,
      updated_at: @sleep_record.updated_at.iso8601
    })
  end

  def update
    # Check if the sleep record belongs to the current user
    unless @sleep_record.user == current_user
      render_error(
        "Sleep record not found",
        "NOT_FOUND",
        {},
        :not_found
      )
      return
    end

    # Check if the sleep record is active (can only clock out active sessions)
    unless @sleep_record.active?
      render_error(
        "No active sleep session found",
        "NO_ACTIVE_SESSION",
        {},
        :unprocessable_entity
      )
      return
    end

    # If wake_time is not provided, use current time
    wake_time = params[:wake_time] || Time.current

    # Update the sleep record
    if @sleep_record.update(wake_time: wake_time)
      render_success({
        id: @sleep_record.id,
        user_id: @sleep_record.user_id,
        bedtime: @sleep_record.bedtime.iso8601,
        wake_time: @sleep_record.wake_time.iso8601,
        duration_minutes: @sleep_record.duration_minutes,
        active: @sleep_record.active?,
        created_at: @sleep_record.created_at.iso8601,
        updated_at: @sleep_record.updated_at.iso8601
      })
    else
      render_validation_error(@sleep_record)
    end
  end

  def index
    sleep_records = current_user.sleep_records.recent_first

    # Apply filters if provided
    sleep_records = sleep_records.completed if params[:completed] == "true"
    sleep_records = sleep_records.active if params[:active] == "true"

    # Apply pagination
    limit = [ params[:limit]&.to_i || 20, 100 ].min # Max 100 records
    offset = params[:offset]&.to_i || 0

    paginated_records = sleep_records.limit(limit).offset(offset)
    total_count = sleep_records.count

    records_data = paginated_records.map do |record|
      {
        id: record.id,
        user_id: record.user_id,
        bedtime: record.bedtime.iso8601,
        wake_time: record.wake_time&.iso8601,
        duration_minutes: record.duration_minutes,
        active: record.active?,
        created_at: record.created_at.iso8601,
        updated_at: record.updated_at.iso8601
      }
    end

    render_success({
      sleep_records: records_data,
      pagination: {
        total_count: total_count,
        limit: limit,
        offset: offset,
        has_more: (offset + limit) < total_count
      }
    })
  end

  def current
    active_session = current_user.sleep_records.active.first

    if active_session
      render_success({
        id: active_session.id,
        user_id: active_session.user_id,
        bedtime: active_session.bedtime.iso8601,
        wake_time: active_session.wake_time,
        duration_minutes: active_session.duration_minutes,
        active: true,
        created_at: active_session.created_at.iso8601,
        updated_at: active_session.updated_at.iso8601
      })
    else
      render_error(
        "No active sleep session found",
        "NO_ACTIVE_SESSION",
        {},
        :not_found
      )
    end
  end

  def destroy
    # Check if the sleep record belongs to the current user
    unless @sleep_record.user == current_user
      render_error(
        "Sleep record not found",
        "NOT_FOUND",
        {},
        :not_found
      )
      return
    end

    # Delete the sleep record
    @sleep_record.destroy
    head :no_content
  end

  private

  def set_sleep_record
    @sleep_record = SleepRecord.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error(
      "Sleep record not found",
      "NOT_FOUND",
      {},
      :not_found
    )
  end

  def sleep_record_params
    # Default bedtime to current time if not provided
    permitted = params.permit(:bedtime, :wake_time)
    permitted[:bedtime] ||= Time.current if action_name == "create"
    permitted
  end
end
