class Api::V1::BaseController < ApplicationController
  include Authenticatable
  include JsonResponder
  include RequestLogger

  rescue_from StandardError, with: :handle_standard_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from ActionController::ParameterMissing, with: :handle_bad_request
  rescue_from ActionController::UnpermittedParameters, with: :handle_unpermitted_parameters
  rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error
  rescue_from ActionController::InvalidAuthenticityToken, with: :handle_invalid_token
  rescue_from JSON::ParserError, with: :handle_json_parse_error

  private

  def handle_standard_error(exception)
    render_internal_error
  end

  def handle_not_found(exception)
    render_not_found
  end

  def handle_bad_request(exception)
    render_error(exception.message, "BAD_REQUEST", {}, :bad_request)
  end

  def handle_unpermitted_parameters(exception)
    render_error("Invalid parameters provided", "INVALID_PARAMETERS", {}, :bad_request)
  end

  def handle_validation_error(exception)
    render_validation_error(exception.record)
  end

  def handle_invalid_token(exception)
    render_error("Invalid or missing authenticity token", "INVALID_TOKEN", {}, :unprocessable_entity)
  end

  def handle_json_parse_error(exception)
    render_error("Invalid JSON format", "INVALID_JSON", {}, :bad_request)
  end
end