# Phase 1 Detailed Plan - Foundation & Basic User Management

## Overview
This document provides a detailed implementation plan for Phase 1 of the Bedtime API. The goal is to establish the project structure, basic user operations, and authentication mechanism using Test-Driven Development.

## Phase Status: 🟡 In Progress

---

## Step 1: Rails Application Setup
**Goal**: Create API-only Rails application with proper configuration

### Tasks Checklist
- [x] Generate new Rails API application
- [x] Configure database (PostgreSQL)
- [x] Set up testing framework
- [x] Configure API-only mode
- [x] Set up development environment
- [x] Create initial project structure

### Tests to Write First
- [x] Application boots successfully
- [x] Database connection works
- [x] API-only configuration is correct
- [x] Test framework is properly configured

### Implementation Details
```bash
# What was actually done:
# 1. Rails 8.0.2 application was pre-generated 
# 2. Updated Gemfile: sqlite3 -> pg gem
# 3. Configured database.yml for PostgreSQL with environment variables
# 4. Fixed docker-compose.yml (removed version warnings, added bundle exec)
# 5. Tested with Docker: docker-compose up -d web
# 6. Verified database connection and Rails server functionality
```

### Acceptance Criteria
- [x] Rails application generates successfully
- [x] Database connection established
- [x] API-only mode configured (no views/helpers)
- [x] Test suite runs without errors
- [x] Development server starts on port 3000

**✅ Step 1 Status: COMPLETED**

---

## Step 2: User Model & Database Schema
**Goal**: Create User model with validations and database migration

### Tasks Checklist
- [x] Generate User model
- [x] Create database migration
- [x] Add model validations
- [x] Set up model associations (prepare for future)
- [x] Run database migration
- [x] Seed basic test data

### Tests to Write First
- [x] User model validation tests
  - [x] Name presence validation
  - [x] Name length validation (reasonable limits)
  - [x] Name format validation (if needed)
- [x] User model creation tests
- [x] User model database constraints tests

### Implementation Details
```ruby
# User model requirements:
class User < ApplicationRecord
  validates :name, presence: true, length: { minimum: 1, maximum: 100 }
  
  # Future associations (prepare but don't implement yet)
  # has_many :sleep_records, dependent: :destroy
  # has_many :follower_relationships, class_name: 'Follow', foreign_key: 'following_id', dependent: :destroy
  # has_many :following_relationships, class_name: 'Follow', foreign_key: 'follower_id', dependent: :destroy
end
```

### Acceptance Criteria
- [x] User model exists with proper validations
- [x] Database migration creates users table correctly
- [x] Model validations prevent invalid users
- [x] Basic test data can be created
- [x] Database constraints match model validations

**✅ Step 2 Status: COMPLETED**

---

## Step 3: API Base Structure
**Goal**: Set up API routing, versioning, and base controller

### Tasks Checklist
- [ ] Set up API routing structure (`/api/v1`)
- [ ] Create base API controller
- [ ] Configure JSON-only responses
- [ ] Set up CORS if needed
- [ ] Create standard error response format
- [ ] Set up logging for API requests

### Tests to Write First
- [ ] API routing tests
- [ ] Base controller functionality tests
- [ ] JSON response format tests
- [ ] Error response format tests

### Implementation Details
```ruby
# config/routes.rb
Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :users, only: [:create]
      # Future endpoints will be added here
    end
  end
end

# app/controllers/api/v1/base_controller.rb
class Api::V1::BaseController < ApplicationController
  rescue_from StandardError, with: :handle_standard_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from ActionController::ParameterMissing, with: :handle_bad_request
  
  private
  
  def handle_standard_error(exception)
    render json: { error: "Internal server error", error_code: "INTERNAL_ERROR" }, status: :internal_server_error
  end
  
  def handle_not_found(exception)
    render json: { error: "Resource not found", error_code: "NOT_FOUND" }, status: :not_found
  end
  
  def handle_bad_request(exception)
    render json: { error: exception.message, error_code: "BAD_REQUEST" }, status: :bad_request
  end
end
```

### Acceptance Criteria
- [ ] API routes are properly namespaced under `/api/v1`
- [ ] Base controller handles common errors
- [ ] JSON responses are consistent
- [ ] Error responses follow standard format
- [ ] API requests are logged properly

---

## Step 4: X-USER-ID Authentication Mechanism
**Goal**: Implement header-based user identification system

### Tasks Checklist
- [ ] Create authentication concern/module
- [ ] Implement X-USER-ID header validation
- [ ] Add user lookup and verification
- [ ] Create authentication helper methods
- [ ] Add authentication to base controller
- [ ] Handle authentication errors gracefully

### Tests to Write First
- [ ] Header validation tests
  - [ ] Missing X-USER-ID header
  - [ ] Empty X-USER-ID header
  - [ ] Invalid user ID (non-existent user)
  - [ ] Valid user ID
- [ ] Authentication helper method tests
- [ ] Current user assignment tests

### Implementation Details
```ruby
# app/controllers/concerns/authenticatable.rb
module Authenticatable
  extend ActiveSupport::Concern
  
  included do
    before_action :authenticate_user, except: [:create] # Skip for user creation
  end
  
  private
  
  def authenticate_user
    user_id = request.headers['X-USER-ID']
    
    if user_id.blank?
      render json: { error: "X-USER-ID header is required", error_code: "MISSING_USER_ID" }, status: :bad_request
      return
    end
    
    @current_user = User.find_by(id: user_id)
    
    if @current_user.nil?
      render json: { error: "User not found", error_code: "USER_NOT_FOUND" }, status: :not_found
      return
    end
  end
  
  def current_user
    @current_user
  end
end
```

### Acceptance Criteria
- [ ] X-USER-ID header is required for protected endpoints
- [ ] Missing header returns 400 with proper error message
- [ ] Invalid user ID returns 404 with proper error message
- [ ] Valid user ID sets current_user correctly
- [ ] Authentication is skipped for user creation endpoint

---

## Step 5: User Creation API Endpoint
**Goal**: Implement testing-only endpoint for creating users

### Tasks Checklist
- [ ] Create Users controller
- [ ] Implement create action
- [ ] Add parameter validation
- [ ] Handle validation errors
- [ ] Return proper JSON responses
- [ ] Add environment-specific logic (development only)

### Tests to Write First
- [ ] User creation success tests
  - [ ] Valid user creation with name
  - [ ] Returns 201 status
  - [ ] Returns correct JSON response
- [ ] User creation failure tests
  - [ ] Missing name parameter
  - [ ] Blank name parameter
  - [ ] Returns 422 status with validation errors
- [ ] Environment restriction tests (if implementing production check)

### Implementation Details
```ruby
# app/controllers/api/v1/users_controller.rb
class Api::V1::UsersController < Api::V1::BaseController
  skip_before_action :authenticate_user, only: [:create]
  
  def create
    # Optional: Restrict to development/test environments
    unless Rails.env.development? || Rails.env.test?
      render json: { error: "Endpoint not available in production", error_code: "FORBIDDEN" }, status: :forbidden
      return
    end
    
    user = User.new(user_params)
    
    if user.save
      render json: {
        id: user.id,
        name: user.name,
        created_at: user.created_at.iso8601
      }, status: :created
    else
      render json: {
        error: "Validation failed",
        error_code: "VALIDATION_ERROR",
        details: user.errors.as_json
      }, status: :unprocessable_entity
    end
  end
  
  private
  
  def user_params
    params.require(:user).permit(:name)
  end
end
```

### Acceptance Criteria
- [ ] POST `/api/v1/users` creates users successfully
- [ ] Returns 201 status with user data
- [ ] Validates required name parameter
- [ ] Returns 422 status for validation errors
- [ ] Error responses include detailed validation messages
- [ ] Endpoint restricted to development/test environments

---

## Step 6: Error Handling & JSON Response Standardization
**Goal**: Ensure consistent error handling and response formats across the API

### Tasks Checklist
- [ ] Standardize JSON response formats
- [ ] Implement comprehensive error handling
- [ ] Add request/response logging
- [ ] Create response helper methods
- [ ] Handle edge cases and unexpected errors
- [ ] Add request validation

### Tests to Write First
- [ ] Standard success response format tests
- [ ] Standard error response format tests
- [ ] Comprehensive error handling tests
- [ ] Logging functionality tests
- [ ] Edge case handling tests

### Implementation Details
```ruby
# app/controllers/concerns/json_responder.rb
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
end
```

### Acceptance Criteria
- [ ] All API responses use consistent JSON format
- [ ] Error responses include error codes and messages
- [ ] Validation errors include detailed field information
- [ ] Unexpected errors are handled gracefully
- [ ] All API requests/responses are logged
- [ ] Response helper methods work correctly

---

## Step 7: Integration Testing & Manual Validation
**Goal**: Verify end-to-end functionality works correctly

### Tasks Checklist
- [ ] Write integration tests for user creation flow
- [ ] Write integration tests for authentication flow
- [ ] Test error scenarios end-to-end
- [ ] Manual testing with curl/Postman
- [ ] Verify Docker environment works
- [ ] Test database persistence

### Tests to Write First
- [ ] Full user creation flow integration tests
- [ ] Authentication flow integration tests
- [ ] Error handling integration tests
- [ ] API routing integration tests

### Manual Testing Commands
```bash
# Test user creation
curl -X POST http://localhost:3000/api/v1/users \
  -H "Content-Type: application/json" \
  -d '{"name": "Test User"}'

# Test authentication (should fail - no protected endpoints yet)
curl -H "X-USER-ID: 1" http://localhost:3000/api/v1/test

# Test error cases
curl -X POST http://localhost:3000/api/v1/users \
  -H "Content-Type: application/json" \
  -d '{}'
```

### Acceptance Criteria
- [ ] Integration tests cover all implemented functionality
- [ ] Manual testing confirms API works as expected
- [ ] Error scenarios are handled properly
- [ ] Docker environment runs the application correctly
- [ ] Database operations work in all environments

---

## Phase 1 Completion Checklist

### Code Quality
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] Code coverage > 90%
- [ ] No rubocop/linting violations
- [ ] No security vulnerabilities detected

### Functionality
- [ ] Rails API application is properly configured
- [ ] User model with validations works correctly
- [ ] X-USER-ID authentication mechanism functions
- [ ] User creation endpoint works in development
- [ ] Error handling is comprehensive and consistent

### Documentation
- [ ] Code is properly documented
- [ ] API endpoints documented
- [ ] README updated with setup instructions
- [ ] Database schema documented

### Testing
- [ ] Unit tests for all components
- [ ] Integration tests for API endpoints
- [ ] Manual testing scenarios validated
- [ ] Error scenarios thoroughly tested

### Review & Deployment
- [ ] Code review completed
- [ ] Docker setup tested
- [ ] CI/CD pipeline configured (if applicable)
- [ ] Ready for Phase 2 development

---

## Common Issues & Solutions

### Database Issues
- **Connection Problems**: Check database.yml configuration
- **Migration Issues**: Ensure PostgreSQL is running and accessible
- **Permission Errors**: Verify database user has proper permissions

### Testing Issues
- **Slow Tests**: Optimize database setup/teardown
- **Flaky Tests**: Ensure proper test isolation
- **Missing Coverage**: Add tests for edge cases and error conditions

### API Issues
- **CORS Problems**: Configure CORS middleware if needed
- **JSON Parsing**: Ensure Content-Type headers are correct
- **Authentication**: Verify X-USER-ID header format and user existence

### Development Environment
- **Docker Issues**: Check docker-compose configuration
- **Port Conflicts**: Ensure port 3000 is available
- **Environment Variables**: Verify all required env vars are set

---

## Success Criteria Summary

Phase 1 is complete when:
1. **✅ All checklist items are completed**
2. **✅ All tests pass with >90% coverage**
3. **✅ Manual testing validates functionality**
4. **✅ Code review approved**
5. **✅ Documentation updated**

**Next Phase**: Move to Phase 2 - Sleep Record Core Functionality