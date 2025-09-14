require "test_helper"

# Test controller to verify authentication concern functionality
class AuthenticatableTestController < ApplicationController
  include Authenticatable

  skip_before_action :authenticate_user, only: [ :test_create_action ]

  def test_action
    render json: { message: "Success", user_id: current_user.id }
  end

  def test_create_action
    render json: { message: "Create action (no auth required)" }
  end
end

class AuthenticatableTest < ActionController::TestCase
  tests AuthenticatableTestController

  setup do
    @user = User.create!(name: "Test User")

    # Add test routes temporarily
    Rails.application.routes.draw do
      get "authenticatable_test/test_action", to: "authenticatable_test#test_action"
      post "authenticatable_test/test_create_action", to: "authenticatable_test#test_create_action"
    end
  end

  teardown do
    # Reload original routes
    Rails.application.reload_routes!
  end

  test "authenticates user with valid X-USER-ID header" do
    request.headers["X-USER-ID"] = @user.id.to_s
    get :test_action

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "Success", json_response["message"]
    assert_equal @user.id, json_response["user_id"]
  end

  test "returns error when X-USER-ID header is missing" do
    get :test_action

    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert_equal "X-USER-ID header is required", json_response["error"]
    assert_equal "MISSING_USER_ID", json_response["error_code"]
  end

  test "returns error when X-USER-ID header is empty" do
    request.headers["X-USER-ID"] = ""
    get :test_action

    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert_equal "X-USER-ID header is required", json_response["error"]
    assert_equal "MISSING_USER_ID", json_response["error_code"]
  end

  test "returns error when X-USER-ID header is whitespace only" do
    request.headers["X-USER-ID"] = "   "
    get :test_action

    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert_equal "X-USER-ID header is required", json_response["error"]
    assert_equal "MISSING_USER_ID", json_response["error_code"]
  end

  test "returns error when user ID does not exist" do
    request.headers["X-USER-ID"] = "99999"
    get :test_action

    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_equal "User not found", json_response["error"]
    assert_equal "USER_NOT_FOUND", json_response["error_code"]
  end

  test "returns error when user ID is invalid format" do
    request.headers["X-USER-ID"] = "invalid"
    get :test_action

    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_equal "User not found", json_response["error"]
    assert_equal "USER_NOT_FOUND", json_response["error_code"]
  end

  test "skips authentication for create action" do
    post :test_create_action

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "Create action (no auth required)", json_response["message"]
  end

  test "current_user returns authenticated user" do
    request.headers["X-USER-ID"] = @user.id.to_s
    get :test_action

    assert_response :success
    # The controller should have access to current_user
    assert_equal @user.id, @controller.send(:current_user).id
  end

  test "current_user returns nil when not authenticated" do
    # Without authentication, current_user should be nil
    assert_nil @controller.send(:current_user)
  end
end
