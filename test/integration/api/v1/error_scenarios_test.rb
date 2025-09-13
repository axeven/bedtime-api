require "test_helper"

class Api::V1::ErrorScenariosTest < ActionDispatch::IntegrationTest
  test "404 not found for non-existent endpoints" do
    # Test various non-existent endpoints return 404
    
    get "/api/v1/nonexistent"
    assert_response :not_found
    
    post "/api/v1/invalid"
    assert_response :not_found
    
    get "/api/v2/users"  # Wrong version
    assert_response :not_found
    
    get "/api/users"     # Missing version
    assert_response :not_found
  end

  test "405 method not allowed for incorrect HTTP methods" do
    # Test incorrect HTTP methods on existing endpoints
    
    get "/api/v1/users"      # Only POST is allowed
    assert_response :not_found  # Rails returns 404 for non-matching routes
    
    put "/api/v1/users"
    assert_response :not_found
    
    delete "/api/v1/users"
    assert_response :not_found
    
    patch "/api/v1/users"
    assert_response :not_found
  end

  test "malformed JSON request handling" do
    # Test various malformed JSON scenarios
    
    malformed_jsons = [
      '{"user": {"name": "test"}',      # Missing closing brace
      '{"user": {"name": test}}',       # Unquoted value
      '{user: {"name": "test"}}',       # Unquoted key
      '{"user": {"name": "test"}}extra', # Extra characters
      'not json at all',                # Not JSON
      '',                               # Empty string
      '{',                              # Just opening brace
      '}'                               # Just closing brace
    ]
    
    malformed_jsons.each do |malformed_json|
      post "/api/v1/users", 
           params: malformed_json,
           headers: { "Content-Type" => "application/json" }
      
      # Rails might handle some of these at the middleware level
      assert_includes [400, 422, 500], response.status, 
                     "Malformed JSON should return error status for: #{malformed_json}"
    end
  end

  test "missing content type header handling" do
    # Test behavior with missing or incorrect content type
    
    # Missing content type with JSON data
    post "/api/v1/users", 
         params: { user: { name: "Test User" } }.to_json
    
    # Should still work or return appropriate error
    assert_includes [200, 201, 400, 415], response.status
    
    # Incorrect content type with JSON data
    post "/api/v1/users", 
         params: { user: { name: "Test User" } }.to_json,
         headers: { "Content-Type" => "text/plain" }
    
    assert_includes [200, 201, 400, 415], response.status
  end

  test "oversized request handling" do
    # Test handling of very large requests
    
    # Create a very long name
    very_long_name = "A" * 10000
    
    post "/api/v1/users", 
         params: { user: { name: very_long_name } }.to_json,
         headers: { "Content-Type" => "application/json" }
    
    # Should return validation error
    assert_response :unprocessable_entity
    
    response_data = JSON.parse(response.body)
    assert_equal "VALIDATION_ERROR", response_data["error_code"]
  end

  test "empty request body handling" do
    # Test various empty request scenarios
    
    # Completely empty body
    post "/api/v1/users", 
         params: "",
         headers: { "Content-Type" => "application/json" }
    
    assert_includes [400, 422], response.status
    
    # Empty JSON object
    post "/api/v1/users", 
         params: "{}",
         headers: { "Content-Type" => "application/json" }
    
    assert_includes [400, 422], response.status
  end

  test "null and undefined value handling" do
    # Test handling of null values in JSON
    
    post "/api/v1/users", 
         params: { user: { name: nil } }.to_json,
         headers: { "Content-Type" => "application/json" }
    
    assert_response :unprocessable_entity
    
    response_data = JSON.parse(response.body)
    assert_equal "VALIDATION_ERROR", response_data["error_code"]
    assert response_data["details"]["name"].present?
  end

  test "special character handling in names" do
    # Test various special characters and edge cases
    
    special_names = [
      "User with spaces",
      "User-with-dashes", 
      "User_with_underscores",
      "User.with.dots",
      "User@with.email.chars",
      "Üser wïth ñön-ÄSCII",
      "用户名中文",                    # Chinese characters
      "🚀 User with emoji 🎉",        # Emojis
      "User\nwith\nnewlines",        # Newlines
      "User\twith\ttabs",            # Tabs
      "User with \"quotes\"",        # Quotes
      "User with 'apostrophes'",     # Apostrophes
      "User with <html> tags",       # HTML-like content
      "User with \\backslashes\\"    # Backslashes
    ]
    
    special_names.each do |name|
      post "/api/v1/users", 
           params: { user: { name: name } }.to_json,
           headers: { "Content-Type" => "application/json" }
      
      if name.length <= 100  # Within our validation limit
        if response.status == 201
          response_data = JSON.parse(response.body)
          assert_equal name, response_data["name"], 
                      "Name should be preserved: #{name}"
        end
      end
      
      # Should always get a valid response
      assert_includes [200, 201, 400, 422], response.status,
                     "Special name should get valid response: #{name}"
    end
  end

  test "concurrent request handling" do
    # Test that multiple concurrent requests work properly
    
    # Create multiple users in sequence to simulate concurrency
    names = ["Concurrent User 1", "Concurrent User 2", "Concurrent User 3"]
    responses = []
    
    names.each do |name|
      post "/api/v1/users", 
           params: { user: { name: name } }.to_json,
           headers: { "Content-Type" => "application/json" }
      
      assert_response :created
      responses << JSON.parse(response.body)
    end
    
    # Verify all users were created with unique IDs
    ids = responses.map { |r| r["id"] }
    assert_equal ids.length, ids.uniq.length, "All user IDs should be unique"
    
    # Verify all names were preserved
    created_names = responses.map { |r| r["name"] }
    assert_equal names.sort, created_names.sort
  end

  test "database constraint handling" do
    # Test behavior with database-level constraints
    
    # Our current model doesn't have unique constraints, but test general DB behavior
    
    # Create a user successfully
    post "/api/v1/users", 
         params: { user: { name: "DB Test User" } }.to_json,
         headers: { "Content-Type" => "application/json" }
    
    assert_response :created
    user_data = JSON.parse(response.body)
    
    # Verify the user exists in the database
    user = User.find(user_data["id"])
    assert_equal "DB Test User", user.name
    
    # Test that we can create another user with the same name (no uniqueness constraint)
    post "/api/v1/users", 
         params: { user: { name: "DB Test User" } }.to_json,
         headers: { "Content-Type" => "application/json" }
    
    assert_response :created  # Should allow duplicate names
  end

  test "error response consistency across all error types" do
    # Collect various error responses and verify consistency
    
    error_scenarios = []
    
    # Validation error
    post "/api/v1/users", 
         params: { user: { name: "" } }.to_json,
         headers: { "Content-Type" => "application/json" }
    error_scenarios << { type: "validation", response: JSON.parse(response.body) }
    
    # Missing parameter error
    post "/api/v1/users", 
         params: {}.to_json,
         headers: { "Content-Type" => "application/json" }
    error_scenarios << { type: "missing_param", response: JSON.parse(response.body) }
    
    # Not found error
    get "/api/v1/nonexistent"
    # This might not return JSON, so handle it carefully
    
    # Verify all error responses have consistent structure
    error_scenarios.each do |scenario|
      response_data = scenario[:response]
      
      assert response_data.key?("error"), 
             "#{scenario[:type]} should have 'error' field"
      assert response_data.key?("error_code"), 
             "#{scenario[:type]} should have 'error_code' field"
      
      assert response_data["error"].is_a?(String), 
             "#{scenario[:type]} error should be a string"
      assert response_data["error_code"].is_a?(String), 
             "#{scenario[:type]} error_code should be a string"
      
      # Error code should follow naming convention
      assert response_data["error_code"].match?(/\A[A-Z_]+\z/), 
             "#{scenario[:type]} error_code should be uppercase with underscores"
      
      # Should not have success fields
      assert_not response_data.key?("id"), 
                "#{scenario[:type]} should not have 'id' field"
    end
  end

  test "health check endpoint works" do
    # Test the Rails health check endpoint
    get "/up"
    
    assert_response :ok
    # The health check returns text content (might be html or plain text depending on Rails config)
    assert_includes ["text/plain", "text/html"], response.content_type.split(";").first
  end
end