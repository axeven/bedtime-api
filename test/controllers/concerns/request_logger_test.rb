require "test_helper"
require "ostruct"

# Test controller to verify RequestLogger concern functionality
class RequestLoggerTestController < ApplicationController
  include RequestLogger

  def success_action
    render json: { message: "Success" }, status: :ok
  end

  def error_action
    raise StandardError, "Test error"
  end

  def validation_error_action
    user = User.new(name: "")
    user.save!
  end

  def custom_response_action
    render json: { custom: "data" }, status: :created
  end
end

class RequestLoggerTest < ActionController::TestCase
  tests RequestLoggerTestController

  setup do
    # Add test routes temporarily
    Rails.application.routes.draw do
      get "request_logger_test/success_action", to: "request_logger_test#success_action"
      get "request_logger_test/error_action", to: "request_logger_test#error_action"
      get "request_logger_test/validation_error_action", to: "request_logger_test#validation_error_action"
      post "request_logger_test/custom_response_action", to: "request_logger_test#custom_response_action"
    end

    # Capture log output for testing
    @log_output = StringIO.new
    @original_logger = Rails.logger
    Rails.logger = Logger.new(@log_output)
  end

  teardown do
    # Restore original logger and routes
    Rails.logger = @original_logger
    Rails.application.reload_routes!
  end

  test "logs successful requests and includes JSON structure" do
    get :success_action

    assert_response :ok

    log_content = @log_output.string
    assert log_content.present?, "Should have logged request"

    # Check that log contains JSON-like structure
    assert_includes log_content, '"type":"api_request"'
    assert_includes log_content, '"method":"GET"'
    assert_includes log_content, '"status":200'
    assert_includes log_content, "success_action"
  end

  test "logs errors with exception details" do
    assert_raises(StandardError) do
      get :error_action
    end

    log_content = @log_output.string

    # Check that error information is logged
    assert_includes log_content, '"error":'
    assert_includes log_content, '"class":"StandardError"'
    assert_includes log_content, '"message":"Test error"'
    assert_includes log_content, '"backtrace":'
    assert_includes log_content, '"status":500'
  end

  test "includes timing information" do
    get :success_action

    log_content = @log_output.string

    # Check for duration_ms field
    assert_includes log_content, '"duration_ms":'
  end

  test "generates request IDs" do
    get :success_action

    log_content = @log_output.string

    # Check for request_id field
    assert_includes log_content, '"request_id":'
  end

  test "captures request parameters" do
    post :custom_response_action, params: { test_param: "test_value", user: { name: "Test" } }

    log_content = @log_output.string

    # Check that parameters are logged
    assert_includes log_content, '"params":'
    assert_includes log_content, '"test_param":"test_value"'
    # Should not include controller/action
    assert_not_includes log_content, '"controller":'
    assert_not_includes log_content, '"action":'
  end

  test "captures relevant headers" do
    @request.headers["X-USER-ID"] = "123"

    get :success_action

    log_content = @log_output.string

    # Check that headers are logged
    assert_includes log_content, '"headers":'
    assert_includes log_content, '"user_id":"123"'
  end

  test "handles different response statuses correctly" do
    post :custom_response_action

    assert_response :created

    log_content = @log_output.string

    # Check response status
    assert_includes log_content, '"status":201'
    assert_includes log_content, '"status_message":"Created"'
  end

  test "includes basic request structure" do
    get :success_action

    log_content = @log_output.string

    # Verify basic structure is present
    assert_includes log_content, '"type":"api_request"'
    assert_includes log_content, '"timestamp":'
    assert_includes log_content, '"request":'
    assert_includes log_content, '"response":'
  end

  test "module is properly included" do
    assert @controller.class.included_modules.include?(RequestLogger)
  end

  private

  def stub_const(const_name, value)
    original_value = Object.const_get(const_name)
    Object.const_set(const_name, value)
    yield
  ensure
    Object.const_set(const_name, original_value)
  end
end
