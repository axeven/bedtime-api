# Phase 2 Detailed Plan - Sleep Record Core Functionality

## Overview
This document provides a detailed implementation plan for Phase 2 of the Bedtime API. The goal is to implement core sleep tracking functionality allowing users to clock in/out and track their sleep sessions using Test-Driven Development.

**Note**: This plan has been updated to integrate the rswag-based TDD approach established in Phase 1.5. All API endpoints should be documented using rswag specs which automatically generate OpenAPI documentation. Templates and helpers are available in `spec/support/` directory.

## Phase Status: 🟡 In Progress (1/7 steps completed)

### Progress Summary
- ✅ **Step 1**: SleepRecord Model & Database Schema - **COMPLETED**
- ⬜ **Step 2**: Clock-In API Endpoint - Not Started
- ⬜ **Step 3**: Clock-Out API Endpoint - Not Started
- ⬜ **Step 4**: Current Active Session Endpoint - Not Started
- ⬜ **Step 5**: Personal Sleep History Endpoint - Not Started
- ⬜ **Step 6**: Duration Calculation & Business Logic - Not Started
- ⬜ **Step 7**: Integration Testing & Manual Validation - Not Started

---

## Step 1: SleepRecord Model & Database Schema
**Goal**: Create SleepRecord model with proper relationships and database migration

### Tasks Checklist
- [x] Generate SleepRecord model
- [x] Create database migration with proper columns
- [x] Add model validations and business rules
- [x] Set up User association (has_many sleep_records)
- [x] Add model methods for duration calculation
- [x] Run database migration and verify schema

### Tests to Write First
**Note**: Use rswag specs for API documentation - templates available in `spec/support/sleep_record_schemas.rb`

- [ ] SleepRecord model validation tests (standard RSpec)
  - [ ] User association presence validation
  - [ ] Bedtime presence validation
  - [ ] Bedtime cannot be in future
  - [ ] Wake_time cannot be before bedtime
  - [ ] Duration calculation accuracy
- [ ] SleepRecord model association tests (standard RSpec)
  - [ ] Belongs to user relationship
  - [ ] User has many sleep_records relationship
- [ ] SleepRecord model business logic tests (standard RSpec)
  - [ ] Active session detection (wake_time is nil)
  - [ ] Completed session detection (both times present)
  - [ ] Duration calculation in minutes

### Implementation Details
```ruby
# SleepRecord model requirements:
class SleepRecord < ApplicationRecord
  belongs_to :user
  
  validates :bedtime, presence: true
  validates :user, presence: true
  validate :bedtime_not_in_future
  validate :wake_time_after_bedtime, if: :wake_time?
  
  scope :completed, -> { where.not(wake_time: nil) }
  scope :active, -> { where(wake_time: nil) }
  scope :for_user, ->(user) { where(user: user) }
  scope :recent_first, -> { order(bedtime: :desc) }
  
  def active?
    wake_time.nil?
  end
  
  def completed?
    bedtime.present? && wake_time.present?
  end
  
  def duration_minutes
    return nil unless completed?
    ((wake_time - bedtime) / 60).round
  end
  
  private
  
  def bedtime_not_in_future
    return unless bedtime
    errors.add(:bedtime, "cannot be in the future") if bedtime > Time.current
  end
  
  def wake_time_after_bedtime
    return unless bedtime && wake_time
    errors.add(:wake_time, "must be after bedtime") if wake_time <= bedtime
  end
end
```

### Database Migration
```ruby
class CreateSleepRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :sleep_records do |t|
      t.references :user, null: false, foreign_key: true
      t.datetime :bedtime, null: false
      t.datetime :wake_time, null: true
      t.integer :duration_minutes, null: true
      t.timestamps
    end
    
    add_index :sleep_records, :user_id
    add_index :sleep_records, :bedtime
    add_index :sleep_records, [:user_id, :bedtime]
  end
end
```

### Acceptance Criteria
- [x] SleepRecord model exists with proper validations
- [x] Database migration creates sleep_records table correctly
- [x] Model prevents invalid sleep records (future bedtime, wake_time before bedtime)
- [x] User association works bidirectionally
- [x] Duration calculation works accurately
- [x] Database constraints match model validations

**✅ Step 1 Status: COMPLETED**

### Implementation Notes
- **Model Created**: `app/models/sleep_record.rb` with full validations and business logic
- **Migration Applied**: `20250914002853_create_sleep_records.rb` - creates table with proper indexes
- **User Association**: Added `has_many :sleep_records, dependent: :destroy` to User model
- **Test Coverage**: 18 passing tests covering all validations, scopes, and business logic
- **Factories Created**: FactoryBot factories for User and SleepRecord with traits
- **Database Schema**: Verified in `db/schema.rb` with correct columns and foreign keys

---

## Step 2: Clock-In API Endpoint
**Goal**: Implement endpoint for users to start a sleep session

### Tasks Checklist
- [ ] Create SleepRecordsController
- [ ] Implement create action for clock-in
- [ ] Add parameter validation and sanitization
- [ ] Add authentication requirement (X-USER-ID)
- [ ] Handle business rule validation (only one active session)
- [ ] Return proper JSON responses

### Tests to Write First
**Note**: Create rswag spec at `spec/requests/api/v1/sleep_records_spec.rb` - template already exists

- [ ] Clock-in rswag spec for POST `/api/v1/sleep_records`
  - [ ] Document successful clock-in (201 response)
  - [ ] Document active session conflict (422 response)
  - [ ] Document authentication required (400 response)
  - [ ] Document user not found (404 response)
  - [ ] Include comprehensive examples using SleepRecordSchemas
  - [ ] Test scenarios: valid bedtime, default bedtime, future bedtime validation
- [ ] Use authentication helpers from `spec/support/authentication_helpers.rb`
- [ ] Leverage existing schemas: ClockInRequest, SleepRecord, ActiveSessionError

### Implementation Details
```ruby
# app/controllers/api/v1/sleep_records_controller.rb
class Api::V1::SleepRecordsController < Api::V1::BaseController
  before_action :authenticate_user
  
  def create
    # Check for existing active session
    existing_active = current_user.sleep_records.active.first
    
    if existing_active
      render_error(
        "You already have an active sleep session",
        "ACTIVE_SESSION_EXISTS",
        { active_session_id: existing_active.id },
        :unprocessable_entity
      )
      return
    end
    
    sleep_record = current_user.sleep_records.build(sleep_record_params)
    
    if sleep_record.save
      render_success({
        id: sleep_record.id,
        user_id: sleep_record.user_id,
        bedtime: sleep_record.bedtime.iso8601,
        wake_time: sleep_record.wake_time,
        duration_minutes: sleep_record.duration_minutes,
        active: sleep_record.active?,
        created_at: sleep_record.created_at.iso8601
      }, :created)
    else
      render_validation_error(sleep_record)
    end
  end
  
  private
  
  def sleep_record_params
    # Default bedtime to current time if not provided
    permitted = params.permit(:bedtime)
    permitted[:bedtime] ||= Time.current
    permitted
  end
end
```

### Routes Addition
```ruby
# config/routes.rb - add to api/v1 namespace
resources :sleep_records, only: [:create, :show, :update, :index] do
  collection do
    get :current
  end
end
```

### Acceptance Criteria
- [ ] POST `/api/v1/sleep_records` creates new sleep session
- [ ] Returns 201 status with sleep record data
- [ ] Requires X-USER-ID header authentication
- [ ] Prevents multiple active sessions per user
- [ ] Sets bedtime to current time by default
- [ ] Validates bedtime is not in future
- [ ] Users can only create their own sleep records

**⬜ Step 2 Status: NOT STARTED**

---

## Step 3: Clock-Out API Endpoint  
**Goal**: Implement endpoint for users to complete a sleep session

### Tasks Checklist
- [ ] Implement update action for clock-out
- [ ] Add parameter validation for wake_time
- [ ] Calculate and store duration automatically
- [ ] Handle business rule validation (session must exist and be active)
- [ ] Add authentication and authorization
- [ ] Return updated sleep record data

### Tests to Write First
**Note**: Update existing rswag spec `spec/requests/api/v1/sleep_records_spec.rb`

- [ ] Clock-out rswag spec for PATCH `/api/v1/sleep_records/:id`
  - [ ] Document successful clock-out (200 response)
  - [ ] Document session already completed error (422 response)
  - [ ] Document session not found (404 response)
  - [ ] Document unauthorized access (403 response)
  - [ ] Document authentication required (400 response)
  - [ ] Include comprehensive examples using SleepRecordSchemas
  - [ ] Test scenarios: default wake_time, explicit wake_time, validation errors
- [ ] Use authentication helpers for X-USER-ID requirement
- [ ] Leverage existing schemas: ClockOutRequest, SleepRecord, NoActiveSessionError

### Implementation Details
```ruby
# Update app/controllers/api/v1/sleep_records_controller.rb
def update
  sleep_record = current_user.sleep_records.find(params[:id])
  
  unless sleep_record.active?
    render_error(
      "Sleep session is already completed",
      "SESSION_ALREADY_COMPLETED",
      { 
        session_id: sleep_record.id,
        completed_at: sleep_record.wake_time&.iso8601
      },
      :unprocessable_entity
    )
    return
  end
  
  # Default wake_time to current time if not provided
  update_params = sleep_record_update_params
  update_params[:wake_time] ||= Time.current
  
  if sleep_record.update(update_params)
    # Calculate duration_minutes automatically
    sleep_record.update_column(:duration_minutes, sleep_record.duration_minutes) if sleep_record.completed?
    
    render_success({
      id: sleep_record.id,
      user_id: sleep_record.user_id,
      bedtime: sleep_record.bedtime.iso8601,
      wake_time: sleep_record.wake_time.iso8601,
      duration_minutes: sleep_record.duration_minutes,
      active: sleep_record.active?,
      updated_at: sleep_record.updated_at.iso8601
    })
  else
    render_validation_error(sleep_record)
  end
rescue ActiveRecord::RecordNotFound
  render_error("Sleep record not found", "NOT_FOUND", {}, :not_found)
end

private

def sleep_record_update_params
  params.permit(:wake_time)
end
```

### Acceptance Criteria
- [ ] PATCH `/api/v1/sleep_records/:id` completes sleep session
- [ ] Returns 200 status with updated sleep record data
- [ ] Requires X-USER-ID header authentication
- [ ] Only updates user's own sleep records
- [ ] Prevents updating already completed sessions
- [ ] Calculates and stores duration automatically
- [ ] Defaults wake_time to current time if not provided
- [ ] Validates wake_time is after bedtime

**⬜ Step 3 Status: NOT STARTED**

---

## Step 4: Current Active Session Endpoint
**Goal**: Allow users to check their current active sleep session

### Tasks Checklist
- [ ] Implement current action for active session retrieval
- [ ] Add authentication requirement
- [ ] Handle case when no active session exists
- [ ] Return consistent JSON response format
- [ ] Add proper error handling

### Tests to Write First
**Note**: Update existing rswag spec `spec/requests/api/v1/sleep_records_spec.rb`

- [ ] Current session rswag spec for GET `/api/v1/sleep_records/current`
  - [ ] Document successful active session retrieval (200 response)
  - [ ] Document no active session found (404 response)
  - [ ] Document authentication required (400 response)
  - [ ] Document user not found (404 response)
  - [ ] Include comprehensive examples using SleepRecordSchemas
  - [ ] Test scenarios: active session exists, no active session, user authorization
- [ ] Use authentication helpers for X-USER-ID requirement
- [ ] Leverage existing schemas: SleepRecord, NoActiveSessionError

### Implementation Details
```ruby
# Add to app/controllers/api/v1/sleep_records_controller.rb
def current
  active_session = current_user.sleep_records.active.first
  
  if active_session
    render_success({
      id: active_session.id,
      user_id: active_session.user_id,
      bedtime: active_session.bedtime.iso8601,
      wake_time: active_session.wake_time,
      duration_minutes: active_session.duration_minutes,
      active: true,
      created_at: active_session.created_at.iso8601
    })
  else
    render_error(
      "No active sleep session found",
      "NO_ACTIVE_SESSION",
      {},
      :not_found
    )
  end
end
```

### Acceptance Criteria
- [ ] GET `/api/v1/sleep_records/current` returns active session
- [ ] Returns 200 status when active session exists
- [ ] Returns 404 status when no active session exists
- [ ] Requires X-USER-ID header authentication
- [ ] Users can only access their own current session
- [ ] Response format matches other sleep record endpoints

**⬜ Step 4 Status: NOT STARTED**

---

## Step 5: Personal Sleep History Endpoint
**Goal**: Allow users to retrieve their sleep history with proper ordering

### Tasks Checklist
- [ ] Implement index action for sleep history
- [ ] Add proper ordering (most recent first)
- [ ] Add pagination support for large datasets
- [ ] Filter for completed sessions only (optional parameter)
- [ ] Add authentication and authorization
- [ ] Include duration information for completed sessions

### Tests to Write First
**Note**: Update existing rswag spec `spec/requests/api/v1/sleep_records_spec.rb`

- [ ] Sleep history rswag spec for GET `/api/v1/sleep_records`
  - [ ] Document successful sleep history retrieval (200 response)
  - [ ] Document empty history (200 response with empty array)
  - [ ] Document authentication required (400 response)
  - [ ] Document user not found (404 response)
  - [ ] Include comprehensive examples using SleepRecordSchemas
  - [ ] Test scenarios: pagination (limit/offset), filtering (completed/active), ordering
  - [ ] Document query parameters for filtering and pagination
- [ ] Use authentication helpers for X-USER-ID requirement
- [ ] Leverage existing schemas: SleepRecordsCollection, SleepRecord

### Implementation Details
```ruby
# Add to app/controllers/api/v1/sleep_records_controller.rb
def index
  sleep_records = current_user.sleep_records.recent_first
  
  # Apply filters if provided
  sleep_records = sleep_records.completed if params[:completed] == 'true'
  sleep_records = sleep_records.active if params[:active] == 'true'
  
  # Apply pagination
  limit = [params[:limit]&.to_i || 20, 100].min # Max 100 records
  offset = params[:offset]&.to_i || 0
  
  paginated_records = sleep_records.limit(limit).offset(offset)
  total_count = sleep_records.count
  
  records_data = paginated_records.map do |record|
    {
      id: record.id,
      bedtime: record.bedtime.iso8601,
      wake_time: record.wake_time&.iso8601,
      duration_minutes: record.duration_minutes,
      active: record.active?,
      created_at: record.created_at.iso8601,
      updated_at: record.updated_at.iso8601
    }
  end
  
  render_success({
    sleep_records: records_data,
    pagination: {
      total_count: total_count,
      limit: limit,
      offset: offset,
      has_more: (offset + limit) < total_count
    }
  })
end
```

### Acceptance Criteria
- [ ] GET `/api/v1/sleep_records` returns user's sleep history
- [ ] Returns 200 status with array of sleep records
- [ ] Records ordered by bedtime (most recent first)
- [ ] Supports pagination with limit/offset parameters
- [ ] Supports filtering by completed/active status
- [ ] Requires X-USER-ID header authentication
- [ ] Users can only access their own sleep records
- [ ] Includes pagination metadata in response

**⬜ Step 5 Status: NOT STARTED**

---

## Step 6: Duration Calculation & Business Logic
**Goal**: Ensure accurate duration calculation and business rule enforcement

### Tasks Checklist
- [ ] Refine duration calculation logic
- [ ] Add business rule validations
- [ ] Handle edge cases (overnight sleep, timezone considerations)
- [ ] Add model callbacks for automatic duration updates
- [ ] Create utility methods for sleep analysis
- [ ] Add data consistency validations

### Tests to Write First
**Note**: Focus on model-level unit tests (standard RSpec) and update rswag specs to document validation errors

- [ ] Duration calculation tests (standard RSpec for model)
  - [ ] Accurate minute calculation for various time ranges
  - [ ] Overnight sleep duration (crosses midnight)
  - [ ] Short naps (under 1 hour)
  - [ ] Long sleep sessions (over 12 hours)
  - [ ] Edge case: exactly midnight bedtime/wake times
- [ ] Business rule tests (standard RSpec for model)
  - [ ] Maximum reasonable sleep duration validation (24 hours)
  - [ ] Minimum reasonable sleep duration validation (1 minute)
  - [ ] Prevent overlapping sleep sessions for same user
- [ ] Callback tests (standard RSpec for model)
  - [ ] Duration calculated automatically on wake_time update
  - [ ] Duration updated when wake_time changes
  - [ ] Duration set to nil when wake_time removed
- [ ] Update rswag specs to document new validation error scenarios

### Implementation Details
```ruby
# Enhanced SleepRecord model
class SleepRecord < ApplicationRecord
  # ... existing code ...
  
  before_save :calculate_duration, if: :will_save_change_to_wake_time?
  
  validate :reasonable_duration, if: :completed?
  validate :no_overlapping_sessions, on: :create
  
  MAX_REASONABLE_SLEEP_HOURS = 24
  MIN_REASONABLE_SLEEP_MINUTES = 1
  
  private
  
  def calculate_duration
    if completed?
      self.duration_minutes = ((wake_time - bedtime) / 60).round
    else
      self.duration_minutes = nil
    end
  end
  
  def reasonable_duration
    return unless duration_minutes
    
    if duration_minutes > (MAX_REASONABLE_SLEEP_HOURS * 60)
      errors.add(:wake_time, "sleep duration cannot exceed #{MAX_REASONABLE_SLEEP_HOURS} hours")
    end
    
    if duration_minutes < MIN_REASONABLE_SLEEP_MINUTES
      errors.add(:wake_time, "sleep duration must be at least #{MIN_REASONABLE_SLEEP_MINUTES} minute")
    end
  end
  
  def no_overlapping_sessions
    return unless bedtime && user
    
    # Check for any overlapping sessions (active sessions or sessions that would overlap)
    overlapping = user.sleep_records
                     .where.not(id: id)
                     .where(
                       "(bedtime <= ? AND (wake_time IS NULL OR wake_time > ?)) OR " \
                       "(bedtime < ? AND wake_time > ?)",
                       bedtime, bedtime, bedtime, bedtime
                     )
                     
    if overlapping.exists?
      errors.add(:bedtime, "overlaps with an existing sleep session")
    end
  end
end
```

### Acceptance Criteria
- [ ] Duration calculated automatically when wake_time is set
- [ ] Duration validation prevents unreasonable sleep durations
- [ ] Overlapping sleep sessions are prevented
- [ ] Duration updates when wake_time is modified
- [ ] Model handles overnight sleep sessions correctly
- [ ] All edge cases are properly handled

**⬜ Step 6 Status: NOT STARTED**

---

## Step 7: Integration Testing & Manual Validation
**Goal**: Verify complete sleep tracking workflow works end-to-end

### Tasks Checklist
- [ ] Write integration tests for complete sleep cycle
- [ ] Write integration tests for error scenarios
- [ ] Test API workflow with concurrent users
- [ ] Manual testing with curl commands
- [ ] Verify Docker environment handles sleep tracking
- [ ] Test database persistence across container restarts

### Tests to Write First
**Note**: Use rswag integration test at `spec/integration/api_documentation_spec.rb` - extend existing test

- [ ] Complete sleep cycle rswag integration tests
  - [ ] Clock-in → check current session → clock-out → view history flow
  - [ ] Multiple users with independent sleep sessions
  - [ ] Error handling throughout the workflow
  - [ ] Validate generated OpenAPI spec includes all sleep record endpoints
- [ ] Edge case integration tests (add to existing rswag specs)
  - [ ] Attempt to clock-in twice without clock-out
  - [ ] Attempt to clock-out without active session
  - [ ] Invalid user access attempts
  - [ ] Malformed request handling
- [ ] Performance integration tests (standard RSpec)
  - [ ] Large sleep history retrieval
  - [ ] Concurrent clock-in/clock-out operations
  - [ ] Database query optimization verification

### Manual Testing Commands
```bash
# Create test users first
curl -X POST http://localhost:3000/api/v1/users \
  -H "Content-Type: application/json" \
  -d '{"user": {"name": "Sleep Tester 1"}}'

curl -X POST http://localhost:3000/api/v1/users \
  -H "Content-Type: application/json" \
  -d '{"user": {"name": "Sleep Tester 2"}}'

# Complete sleep tracking workflow for User 1
# 1. Clock-in
curl -X POST http://localhost:3000/api/v1/sleep_records \
  -H "Content-Type: application/json" \
  -H "X-USER-ID: 1"

# 2. Check current session
curl -H "X-USER-ID: 1" http://localhost:3000/api/v1/sleep_records/current

# 3. Clock-out after some time
curl -X PATCH http://localhost:3000/api/v1/sleep_records/1 \
  -H "Content-Type: application/json" \
  -H "X-USER-ID: 1"

# 4. View sleep history
curl -H "X-USER-ID: 1" http://localhost:3000/api/v1/sleep_records

# Error scenarios testing
# Try to clock-in twice
curl -X POST http://localhost:3000/api/v1/sleep_records \
  -H "Content-Type: application/json" \
  -H "X-USER-ID: 1"

# Try to access another user's session
curl -H "X-USER-ID: 2" http://localhost:3000/api/v1/sleep_records/1

# Try without authentication
curl http://localhost:3000/api/v1/sleep_records/current
```

### Testing Approach
**rswag Integration**: The existing rswag spec template at `spec/requests/api/v1/sleep_records_spec.rb` should be enhanced with all test scenarios above.

**Documentation Generation**: After implementing each step, run:
```bash
# Generate updated API documentation
docker-compose exec web bundle exec rake api_docs:generate

# Validate documentation
docker-compose exec web bundle exec rake api_docs:validate
```

### Acceptance Criteria
- [ ] Complete sleep tracking workflow works end-to-end
- [ ] All error scenarios are handled properly
- [ ] Multiple users can track sleep independently
- [ ] Authorization prevents unauthorized access
- [ ] Database operations work correctly in all environments
- [ ] Manual testing confirms API functionality
- [ ] Performance is acceptable for expected usage

**⬜ Step 7 Status: NOT STARTED**

---

## Phase 2 Completion Checklist

### Code Quality
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] Code coverage > 90%
- [ ] No rubocop/linting violations
- [ ] No security vulnerabilities detected

### Functionality
- [ ] SleepRecord model with proper validations and associations
- [ ] Clock-in API endpoint works correctly
- [ ] Clock-out API endpoint works correctly
- [ ] Current session retrieval works correctly
- [ ] Sleep history retrieval with pagination works correctly
- [ ] Duration calculation is accurate and automatic
- [ ] All business rules are properly enforced

### API Design
- [ ] RESTful endpoint design follows conventions
- [ ] Consistent JSON response formats across all endpoints
- [ ] Proper HTTP status codes for all scenarios
- [ ] Authentication required for all sleep record operations
- [ ] Authorization prevents unauthorized access to sleep data

### Testing
- [ ] Unit tests for all model validations and business logic
- [ ] Integration tests for all API endpoints
- [ ] Manual testing scenarios validated
- [ ] Error scenarios thoroughly tested
- [ ] Performance testing for sleep history retrieval

### Documentation
- [ ] API endpoints documented with rswag specs and OpenAPI generation
- [ ] Model relationships and validations documented in code comments
- [ ] Business rules clearly documented in rswag spec descriptions
- [ ] Database schema changes documented in migration files
- [ ] OpenAPI specification generated and validated for all new endpoints

### Review & Deployment
- [ ] Code review completed
- [ ] Docker setup tested with new functionality
- [ ] Database migrations tested
- [ ] Ready for Phase 3 development

---

## Common Issues & Solutions

### Database Issues
- **Duration Calculation**: Ensure proper timezone handling for accurate calculations
- **Overlapping Sessions**: Implement robust validation to prevent data conflicts
- **Migration Issues**: Test migrations with existing data

### API Issues
- **Concurrent Access**: Handle race conditions for clock-in/clock-out operations
- **Large History**: Implement efficient pagination for users with many sleep records
- **Timezone Handling**: Consider user timezones for bedtime/wake_time

### Business Logic Issues
- **Edge Cases**: Handle overnight sleep, very short/long sessions
- **Data Integrity**: Ensure duration calculations remain consistent
- **User Experience**: Provide clear error messages for business rule violations

### Testing Issues
- **Time-based Testing**: Use proper time mocking for consistent test results
- **Integration Complexity**: Break down complex workflows into smaller testable units
- **Data Setup**: Create efficient test data setup for various scenarios

---

## Success Criteria Summary

Phase 2 is complete when:
1. **⬜ All checklist items are completed**
2. **⬜ All tests pass with >90% coverage**
3. **⬜ All rswag specs generate valid OpenAPI documentation**
4. **⬜ Manual testing validates functionality**
5. **⬜ Code review approved**
6. **⬜ Documentation updated and validated**

**Next Phase**: Move to Phase 3 - Social Following System

---

## API Endpoint Summary

Upon completion, Phase 2 will provide these endpoints:

| Method | Endpoint | Purpose | Auth Required |
|--------|----------|---------|---------------|
| POST | `/api/v1/sleep_records` | Clock-in (start sleep session) | Yes |
| PATCH | `/api/v1/sleep_records/:id` | Clock-out (end sleep session) | Yes |
| GET | `/api/v1/sleep_records/current` | Get current active session | Yes |
| GET | `/api/v1/sleep_records` | Get sleep history with pagination | Yes |

**Authentication**: All endpoints require `X-USER-ID` header
**Authorization**: Users can only access their own sleep records
**Response Format**: Consistent JSON with proper error codes