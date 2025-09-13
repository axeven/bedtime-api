require "test_helper"

class Api::V1::UsersControllerTest < ActionDispatch::IntegrationTest
  test "creates user with valid name" do
    assert_difference 'User.count', 1 do
      post api_v1_users_path, params: { user: { name: "Test User" } }
    end

    assert_response :created
    json_response = JSON.parse(response.body)
    
    assert json_response["id"].present?
    assert_equal "Test User", json_response["name"]
    assert json_response["created_at"].present?
    
    # Verify it's a valid ISO8601 timestamp
    assert_nothing_raised { DateTime.iso8601(json_response["created_at"]) }
  end

  test "returns 201 status for successful user creation" do
    post api_v1_users_path, params: { user: { name: "Another User" } }
    
    assert_response :created
  end

  test "returns correct JSON response format for successful creation" do
    post api_v1_users_path, params: { user: { name: "JSON Test User" } }
    
    json_response = JSON.parse(response.body)
    
    # Check required fields are present
    assert json_response.key?("id")
    assert json_response.key?("name")
    assert json_response.key?("created_at")
    
    # Check no extra fields are present
    assert_equal 3, json_response.keys.length
  end

  test "fails when name parameter is missing from user object" do
    assert_no_difference 'User.count' do
      post api_v1_users_path, params: { user: { other_field: "value" } }
    end

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    
    assert_equal "Validation failed", json_response["error"]
    assert_equal "VALIDATION_ERROR", json_response["error_code"]
    assert json_response["details"].present?
  end

  test "fails when name is blank" do
    assert_no_difference 'User.count' do
      post api_v1_users_path, params: { user: { name: "" } }
    end

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    
    assert_equal "Validation failed", json_response["error"]
    assert_equal "VALIDATION_ERROR", json_response["error_code"]
    assert json_response["details"]["name"].include?("can't be blank")
  end

  test "fails when name is only whitespace" do
    assert_no_difference 'User.count' do
      post api_v1_users_path, params: { user: { name: "   " } }
    end

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    
    assert_equal "Validation failed", json_response["error"]
    assert_equal "VALIDATION_ERROR", json_response["error_code"]
    assert json_response["details"]["name"].include?("can't be blank")
  end

  test "fails when name is too long" do
    long_name = "A" * 101
    
    assert_no_difference 'User.count' do
      post api_v1_users_path, params: { user: { name: long_name } }
    end

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    
    assert_equal "Validation failed", json_response["error"]
    assert_equal "VALIDATION_ERROR", json_response["error_code"]
    assert json_response["details"]["name"].include?("is too long (maximum is 100 characters)")
  end

  test "fails when user parameter is missing entirely" do
    assert_no_difference 'User.count' do
      post api_v1_users_path, params: {}
    end

    assert_response :bad_request
    json_response = JSON.parse(response.body)
    
    assert_equal "BAD_REQUEST", json_response["error_code"]
    assert json_response["error"].include?("param is missing")
  end

  test "fails when user parameter is empty hash" do
    assert_no_difference 'User.count' do
      post api_v1_users_path, params: { user: {} }
    end

    assert_response :bad_request
    json_response = JSON.parse(response.body)
    
    assert_equal "BAD_REQUEST", json_response["error_code"]
    assert json_response["error"].include?("param is missing")
  end

  test "returns 422 status for validation errors" do
    post api_v1_users_path, params: { user: { name: "" } }
    
    assert_response :unprocessable_entity
  end

  test "validation error response includes detailed field information" do
    post api_v1_users_path, params: { user: { name: "" } }
    
    json_response = JSON.parse(response.body)
    
    assert json_response["details"].present?
    assert json_response["details"]["name"].present?
    assert json_response["details"]["name"].is_a?(Array)
  end

  test "does not require authentication" do
    # This should work without X-USER-ID header
    post api_v1_users_path, params: { user: { name: "No Auth User" } }
    
    assert_response :created
  end

  # Environment restriction tests (this will pass in test environment)
  test "allows creation in test environment" do
    post api_v1_users_path, params: { user: { name: "Test Env User" } }
    
    assert_response :created
  end
end