module RequestLogger
  extend ActiveSupport::Concern

  included do
    around_action :log_request_response
  end

  private

  def log_request_response
    return yield unless should_log?

    request_id = generate_request_id
    start_time = Time.current
    request_data = capture_request_data(request_id)

    begin
      yield
    rescue => exception
      log_complete_request(request_data, nil, exception, start_time)
      raise
    end

    response_data = capture_response_data
    log_complete_request(request_data, response_data, nil, start_time)
  end

  def generate_request_id
    # Use Rails request ID if available, otherwise generate one
    request.request_id || SecureRandom.hex(8)
  end

  def capture_request_data(request_id)
    {
      request_id: request_id,
      method: request.method,
      path: request.path,
      params: params.except(:controller, :action, :format).as_json,
      headers: {
        user_id: request.headers["X-USER-ID"],
        content_type: request.content_type,
        user_agent: request.user_agent
      }.compact,
      ip: request.remote_ip
    }
  end

  def capture_response_data
    {
      status: response.status,
      status_message: Rack::Utils::HTTP_STATUS_CODES[response.status]
    }
  end

  def log_complete_request(request_data, response_data, exception, start_time)
    duration_ms = ((Time.current - start_time) * 1000).round(2)

    log_entry = {
      timestamp: Time.current.iso8601,
      type: "api_request",
      duration_ms: duration_ms,
      request: request_data
    }

    if exception
      log_entry[:error] = {
        class: exception.class.name,
        message: exception.message,
        backtrace: exception.backtrace&.first(5) # Limit backtrace for readability
      }
      log_entry[:response] = {
        status: 500,
        status_message: "Internal Server Error"
      }
    else
      log_entry[:response] = response_data
    end

    # Add response body for errors or if specifically requested
    if should_log_response_body?(exception)
      log_entry[:response][:body] = parse_response_body
    end

    Rails.logger.info(log_entry.to_json)
  end

  def should_log?
    Rails.env.development? || Rails.env.test? || ENV["ENABLE_REQUEST_LOGGING"] == "true"
  end

  def should_log_response_body?(exception)
    # Log response body for errors or in development
    exception.present? || Rails.env.development?
  end

  def parse_response_body
    return nil unless response.body.present?

    # Try to parse as JSON, fallback to string
    JSON.parse(response.body)
  rescue JSON::ParserError
    response.body.truncate(500) # Limit large responses
  end
end
