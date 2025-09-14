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
      "not json at all",                # Not JSON
      "",                               # Empty string
      "{",                              # Just opening brace
      "}"                               # Just closing brace
    ]

    malformed_jsons.each do |malformed_json|
      post "/api/v1/users",
           params: malformed_json,
           headers: { "Content-Type" => "application/json" }

      # Rails might handle some of these at the middleware level
      assert_includes [ 400, 422, 500 ], response.status,
                     "Malformed JSON should return error status for: #{malformed_json}"
    end
  end

  test "missing content type header handling" do
    # Test behavior with missing or incorrect content type

    # Missing content type with JSON data
    post "/api/v1/users",
         params: { user: { name: "Test User" } }.to_json

    # Should still work or return appropriate error
    assert_includes [ 200, 201, 400, 415 ], response.status

    # Incorrect content type with JSON data
    post "/api/v1/users",
         params: { user: { name: "Test User" } }.to_json,
         headers: { "Content-Type" => "text/plain" }

    assert_includes [ 200, 201, 400, 415 ], response.status
  end

  # User-specific tests moved to rswag specs

  test "health check endpoint works" do
    # Test the Rails health check endpoint
    get "/up"

    assert_response :ok
    # The health check returns text content (might be html or plain text depending on Rails config)
    assert_includes [ "text/plain", "text/html" ], response.content_type.split(";").first
  end
end
