class Api::V1::BaseController < ApplicationController
  include Authenticatable

  rescue_from StandardError, with: :handle_standard_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from ActionController::ParameterMissing, with: :handle_bad_request
  rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error

  private

  def handle_standard_error(exception)
    Rails.logger.error "Standard Error: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n") if exception.backtrace
    render json: { 
      error: "Internal server error", 
      error_code: "INTERNAL_ERROR" 
    }, status: :internal_server_error
  end

  def handle_not_found(exception)
    render json: { 
      error: "Resource not found", 
      error_code: "NOT_FOUND" 
    }, status: :not_found
  end

  def handle_bad_request(exception)
    render json: { 
      error: exception.message, 
      error_code: "BAD_REQUEST" 
    }, status: :bad_request
  end

  def handle_validation_error(exception)
    render json: {
      error: "Validation failed",
      error_code: "VALIDATION_ERROR",
      details: exception.record.errors.as_json
    }, status: :unprocessable_entity
  end

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
end