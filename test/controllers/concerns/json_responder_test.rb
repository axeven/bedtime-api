require "test_helper"

# Test controller to verify JsonResponder concern functionality
class JsonResponderTestController < ApplicationController
  include JsonResponder

  def test_render_success
    render_success({ message: "Success" }, :created)
  end

  def test_render_error
    render_error("Test error", "TEST_ERROR", { field: "value" }, :bad_request)
  end

  def test_render_validation_error
    user = User.new(name: "")
    user.validate
    render_validation_error(user)
  end

  def test_render_not_found
    render_not_found("Custom not found message")
  end

  def test_render_unauthorized
    render_unauthorized
  end

  def test_render_forbidden
    render_forbidden("Custom forbidden message")
  end

  def test_render_internal_error
    render_internal_error
  end
end

class JsonResponderTest < ActionController::TestCase
  tests JsonResponderTestController

  setup do
    # Add test routes temporarily
    Rails.application.routes.draw do
      get 'json_responder_test/test_render_success', to: 'json_responder_test#test_render_success'
      get 'json_responder_test/test_render_error', to: 'json_responder_test#test_render_error'
      get 'json_responder_test/test_render_validation_error', to: 'json_responder_test#test_render_validation_error'
      get 'json_responder_test/test_render_not_found', to: 'json_responder_test#test_render_not_found'
      get 'json_responder_test/test_render_unauthorized', to: 'json_responder_test#test_render_unauthorized'
      get 'json_responder_test/test_render_forbidden', to: 'json_responder_test#test_render_forbidden'
      get 'json_responder_test/test_render_internal_error', to: 'json_responder_test#test_render_internal_error'
    end
  end

  teardown do
    # Reload original routes
    Rails.application.reload_routes!
  end

  test "render_success returns proper JSON response with custom status" do
    get :test_render_success
    
    assert_response :created
    json_response = JSON.parse(response.body)
    assert_equal "Success", json_response["message"]
  end

  test "render_error returns proper JSON response with details" do
    get :test_render_error
    
    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert_equal "Test error", json_response["error"]
    assert_equal "TEST_ERROR", json_response["error_code"]
    assert_equal "value", json_response["details"]["field"]
  end

  test "render_validation_error returns proper JSON response" do
    get :test_render_validation_error
    
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_equal "Validation failed", json_response["error"]
    assert_equal "VALIDATION_ERROR", json_response["error_code"]
    assert json_response["details"].present?
  end

  test "render_not_found returns proper JSON response" do
    get :test_render_not_found
    
    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_equal "Custom not found message", json_response["error"]
    assert_equal "NOT_FOUND", json_response["error_code"]
  end

  test "render_unauthorized returns proper JSON response" do
    get :test_render_unauthorized
    
    assert_response :unauthorized
    json_response = JSON.parse(response.body)
    assert_equal "Unauthorized access", json_response["error"]
    assert_equal "UNAUTHORIZED", json_response["error_code"]
  end

  test "render_forbidden returns proper JSON response with custom message" do
    get :test_render_forbidden
    
    assert_response :forbidden
    json_response = JSON.parse(response.body)
    assert_equal "Custom forbidden message", json_response["error"]
    assert_equal "FORBIDDEN", json_response["error_code"]
  end

  test "render_internal_error returns proper JSON response" do
    get :test_render_internal_error
    
    assert_response :internal_server_error
    json_response = JSON.parse(response.body)
    assert_equal "Internal server error", json_response["error"]
    assert_equal "INTERNAL_ERROR", json_response["error_code"]
  end

  test "all error responses have consistent format" do
    # Test multiple error types for consistent structure
    error_methods = [
      :test_render_error,
      :test_render_not_found,
      :test_render_unauthorized,
      :test_render_forbidden,
      :test_render_internal_error
    ]

    error_methods.each do |method|
      get method
      json_response = JSON.parse(response.body)
      
      # All error responses should have error and error_code
      assert json_response.key?("error"), "#{method} missing 'error' field"
      assert json_response.key?("error_code"), "#{method} missing 'error_code' field"
      
      # error and error_code should be strings
      assert json_response["error"].is_a?(String), "#{method} error should be string"
      assert json_response["error_code"].is_a?(String), "#{method} error_code should be string"
    end
  end

  test "success responses do not include error fields" do
    get :test_render_success
    json_response = JSON.parse(response.body)
    
    assert_not json_response.key?("error")
    assert_not json_response.key?("error_code")
  end
end