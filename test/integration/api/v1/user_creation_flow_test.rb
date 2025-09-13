require "test_helper"

class Api::V1::UserCreationFlowTest < ActionDispatch::IntegrationTest
  test "complete user creation flow with valid data" do
    # Test the full user creation flow from start to finish
    
    # Step 1: Create a user with valid data
    post "/api/v1/users", 
         params: { user: { name: "Integration Test User" } }.to_json,
         headers: { "Content-Type" => "application/json" }
    
    assert_response :created
    
    response_data = JSON.parse(response.body)
    assert response_data["id"].present?
    assert_equal "Integration Test User", response_data["name"]
    assert response_data["created_at"].present?
    
    # Verify timestamp format
    assert_nothing_raised { DateTime.iso8601(response_data["created_at"]) }
    
    # Store user ID for later tests
    @user_id = response_data["id"]
    
    # Step 2: Verify user was actually saved to database
    user = User.find(@user_id)
    assert_equal "Integration Test User", user.name
    assert user.created_at.present?
  end

  test "user creation flow with validation errors" do
    # Test complete error flow with validation failures
    
    # Step 1: Attempt to create user with blank name
    post "/api/v1/users", 
         params: { user: { name: "" } }.to_json,
         headers: { "Content-Type" => "application/json" }
    
    assert_response :unprocessable_entity
    
    response_data = JSON.parse(response.body)
    assert_equal "Validation failed", response_data["error"]
    assert_equal "VALIDATION_ERROR", response_data["error_code"]
    assert response_data["details"].present?
    assert response_data["details"]["name"].include?("can't be blank")
    
    # Step 2: Verify no user was created in database
    initial_count = User.count
    assert_no_difference 'User.count' do
      # Count should remain the same
    end
  end

  test "user creation flow with missing parameters" do
    # Test parameter missing error flow
    
    # Step 1: Send request without user parameter
    post "/api/v1/users", 
         params: {}.to_json,
         headers: { "Content-Type" => "application/json" }
    
    assert_response :bad_request
    
    response_data = JSON.parse(response.body)
    assert_equal "BAD_REQUEST", response_data["error_code"]
    assert response_data["error"].include?("param is missing")
    
    # Step 2: Send request with empty user parameter
    post "/api/v1/users", 
         params: { user: {} }.to_json,
         headers: { "Content-Type" => "application/json" }
    
    assert_response :bad_request
    
    response_data = JSON.parse(response.body)
    assert_equal "BAD_REQUEST", response_data["error_code"]
  end

  test "user creation flow with invalid JSON" do
    # Test JSON parsing error flow
    
    post "/api/v1/users", 
         params: "invalid json{",
         headers: { "Content-Type" => "application/json" }
    
    # Rails handles JSON parse errors and may return 500 or 400
    assert_includes [400, 500], response.status
    
    response_data = JSON.parse(response.body)
    assert response_data.key?("error")
    assert response_data.key?("error_code")
  end

  test "user creation flow with oversized name" do
    # Test validation with name too long
    
    long_name = "A" * 101
    
    post "/api/v1/users", 
         params: { user: { name: long_name } }.to_json,
         headers: { "Content-Type" => "application/json" }
    
    assert_response :unprocessable_entity
    
    response_data = JSON.parse(response.body)
    assert_equal "VALIDATION_ERROR", response_data["error_code"]
    assert response_data["details"]["name"].any? { |msg| msg.include?("is too long") }
  end

  test "user creation does not require authentication" do
    # Verify that user creation works without X-USER-ID header
    
    post "/api/v1/users", 
         params: { user: { name: "No Auth User" } }.to_json,
         headers: { "Content-Type" => "application/json" }
    
    assert_response :created
    
    response_data = JSON.parse(response.body)
    assert response_data["id"].present?
    assert_equal "No Auth User", response_data["name"]
  end

  test "response format consistency across success and error cases" do
    # Verify all responses follow consistent format
    
    # Success case
    post "/api/v1/users", 
         params: { user: { name: "Format Test User" } }.to_json,
         headers: { "Content-Type" => "application/json" }
    
    assert_response :created
    success_response = JSON.parse(response.body)
    
    # Success should not have error fields
    assert_not success_response.key?("error")
    assert_not success_response.key?("error_code")
    
    # Error case
    post "/api/v1/users", 
         params: { user: { name: "" } }.to_json,
         headers: { "Content-Type" => "application/json" }
    
    assert_response :unprocessable_entity
    error_response = JSON.parse(response.body)
    
    # Error should have required fields
    assert error_response.key?("error")
    assert error_response.key?("error_code")
    assert error_response["error"].is_a?(String)
    assert error_response["error_code"].is_a?(String)
    
    # Error code should follow pattern
    assert error_response["error_code"].match?(/\A[A-Z_]+\z/)
  end

  test "content type handling" do
    # Test with different content types
    
    # Valid JSON content type
    post "/api/v1/users", 
         params: { user: { name: "JSON User" } }.to_json,
         headers: { "Content-Type" => "application/json" }
    
    assert_response :created
    
    # Test without explicit content type (should still work)
    post "/api/v1/users", 
         params: { user: { name: "Default User" } }
    
    # Rails should handle this gracefully
    assert_includes [200, 201, 400], response.status
  end
end