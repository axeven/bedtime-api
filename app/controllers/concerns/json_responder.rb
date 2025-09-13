module JsonResponder
  extend ActiveSupport::Concern

  private

  def render_success(data = {}, status = :ok)
    render json: data, status: status
  end

  def render_error(message, code = "ERROR", details = {}, status = :bad_request)
    error_response = {
      error: message,
      error_code: code
    }
    error_response[:details] = details unless details.empty?
    
    render json: error_response, status: status
  end

  def render_validation_error(model)
    render_error(
      "Validation failed",
      "VALIDATION_ERROR",
      model.errors.as_json,
      :unprocessable_entity
    )
  end

  def render_not_found(message = "Resource not found")
    render_error(message, "NOT_FOUND", {}, :not_found)
  end

  def render_unauthorized(message = "Unauthorized access")
    render_error(message, "UNAUTHORIZED", {}, :unauthorized)
  end

  def render_forbidden(message = "Access forbidden")
    render_error(message, "FORBIDDEN", {}, :forbidden)
  end

  def render_internal_error(message = "Internal server error")
    render_error(message, "INTERNAL_ERROR", {}, :internal_server_error)
  end

end