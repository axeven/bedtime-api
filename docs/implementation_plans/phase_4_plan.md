# Phase 4 Detailed Plan - Social Sleep Data Access

## Overview
This document provides a detailed implementation plan for Phase 4 of the Bedtime API. The goal is to enable viewing sleep records from followed users, implementing social features for sleep data sharing, using Test-Driven Development with rswag integration.

**Note**: This phase builds on the social following system from Phase 3 and the sleep record functionality from Phase 2. All API endpoints should be documented using rswag specs which automatically generate OpenAPI documentation. Authentication helpers and patterns are available in `spec/support/` directory.

## Phase Status: 🟡 In Progress (1/7 steps completed)

### Progress Summary
- ✅ **Step 1**: Social Sleep Data Model Enhancements - **COMPLETED**
- ⬜ **Step 2**: Following Users' Sleep Records Endpoint - **Not Started**
- ⬜ **Step 3**: Date Range Filtering Implementation - **Not Started**
- ⬜ **Step 4**: Duration-Based Sorting & Aggregation - **Not Started**
- ⬜ **Step 5**: Complete Records Filter & Privacy Controls - **Not Started**
- ⬜ **Step 6**: Pagination & Performance Optimization - **Not Started**
- ⬜ **Step 7**: Integration Testing & Manual Validation - **Not Started**

---

## Step 1: Social Sleep Data Model Enhancements
**Goal**: Enhance SleepRecord model and database schema for social querying capabilities

### Tasks Checklist
- [x] Add database indexes for social queries (user_id, bedtime, wake_time, duration)
- [x] Create SleepRecord scopes for social data access
- [x] Add completed_records scope (both bedtime and wake_time present)
- [x] Add recent_records scope (last 7 days)
- [x] Add by_duration scope (ordered by duration)
- [x] Create social query helper methods
- [x] Verify database performance with EXPLAIN queries

### Tests to Write First
**Note**: Use standard RSpec for model tests, rswag for API documentation

- [x] SleepRecord model scope tests (standard RSpec)
  - [x] `completed_records` scope returns only records with both bedtime and wake_time
  - [x] `recent_records` scope returns records from last 7 days
  - [x] `by_duration` scope orders by duration (longest first)
  - [x] `for_social_feed` scope combines completed + recent + ordered
  - [x] Performance tests for large datasets (1000+ records)
- [x] Social query helper method tests (standard RSpec)
  - [x] `SleepRecord.social_feed_for_user(user)` returns followed users' records
  - [x] Social feed respects privacy (only followed users' data)
  - [x] Social feed excludes incomplete records
  - [x] Social feed includes user identification

### Implementation Details
```ruby
# Update app/models/sleep_record.rb
class SleepRecord < ApplicationRecord
  belongs_to :user

  validates :bedtime, presence: true
  validates :user, presence: true

  # Existing scopes...
  scope :for_user, ->(user) { where(user: user) }
  scope :active, -> { where(wake_time: nil) }
  scope :completed, -> { where.not(wake_time: nil) }

  # New social scopes
  scope :completed_records, -> { where.not(bedtime: nil).where.not(wake_time: nil) }
  scope :recent_records, ->(days = 7) { where(bedtime: days.days.ago..Time.current) }
  scope :by_duration, -> { order(duration_minutes: :desc) }
  scope :for_social_feed, -> { completed_records.recent_records.by_duration }

  # Social query helper methods
  def self.social_feed_for_user(user)
    followed_user_ids = user.following_users.pluck(:id)
    return none if followed_user_ids.empty?

    includes(:user)
      .where(user_id: followed_user_ids)
      .for_social_feed
  end

  def self.social_feed_with_pagination(user, limit: 20, offset: 0)
    social_feed_for_user(user)
      .limit(limit)
      .offset(offset)
  end

  # Helper methods for display
  def user_name
    user.name
  end

  def sleep_date
    bedtime&.to_date
  end

  def formatted_duration
    return nil unless duration_minutes
    hours = duration_minutes / 60
    minutes = duration_minutes % 60
    "#{hours}h #{minutes}m"
  end
end
```

```ruby
# Database migration for indexes
class AddSocialIndexesToSleepRecords < ActiveRecord::Migration[8.0]
  def change
    # Composite index for social queries (user + date range)
    add_index :sleep_records, [:user_id, :bedtime], name: 'index_sleep_records_on_user_and_bedtime'

    # Index for duration sorting
    add_index :sleep_records, :duration_minutes, name: 'index_sleep_records_on_duration'

    # Composite index for completed records in date range
    add_index :sleep_records, [:bedtime, :wake_time], name: 'index_sleep_records_on_completion_and_date'

    # Index for efficient social feed queries
    add_index :sleep_records, [:user_id, :bedtime, :wake_time, :duration_minutes],
              name: 'index_sleep_records_social_feed'
  end
end
```

### Acceptance Criteria
- [x] SleepRecord model has efficient scopes for social queries
- [x] Database indexes support fast social feed generation
- [x] Only completed records (with both bedtime and wake_time) included
- [x] Recent records scope properly filters last 7 days
- [x] Duration-based ordering works correctly
- [x] Social feed helper methods respect privacy boundaries

---

## Step 2: Following Users' Sleep Records Endpoint
**Goal**: Implement API endpoint to retrieve sleep records from users that current user follows

### Tasks Checklist
- [ ] Create social_sleep_records_controller.rb or add to existing controller
- [ ] Implement GET /api/v1/following/sleep_records endpoint
- [ ] Add proper authentication and authorization
- [ ] Implement basic social feed functionality
- [ ] Return sleep record data with user identification
- [ ] Add proper error handling for edge cases

### Tests to Write First
**Use rswag for API documentation**

- [ ] rswag API specs for social sleep records (in `spec/requests/api/v1/social_sleep_records_spec.rb`)
  - [ ] Successful retrieval with results (200)
  - [ ] Empty results for user following no one (200)
  - [ ] Authentication required (400)
  - [ ] Only followed users' records returned
  - [ ] Only completed records included
  - [ ] User identification included in response

### Implementation Details
```ruby
# config/routes.rb - add to api/v1 namespace
namespace :following do
  resources :sleep_records, only: [:index]
end

# app/controllers/api/v1/following/sleep_records_controller.rb
class Api::V1::Following::SleepRecordsController < Api::V1::BaseController
  before_action :authenticate_user

  def index
    sleep_records = SleepRecord.social_feed_for_user(current_user)

    if sleep_records.empty?
      render_success({
        sleep_records: [],
        message: "No sleep records found. Follow users to see their sleep data!"
      })
      return
    end

    records_data = sleep_records.map do |record|
      {
        id: record.id,
        user_id: record.user_id,
        user_name: record.user_name,
        bedtime: record.bedtime.iso8601,
        wake_time: record.wake_time.iso8601,
        duration_minutes: record.duration_minutes,
        formatted_duration: record.formatted_duration,
        sleep_date: record.sleep_date.iso8601,
        created_at: record.created_at.iso8601
      }
    end

    render_success({
      sleep_records: records_data,
      total_count: records_data.length
    })
  end
end
```

### API Specification (rswag)
```ruby
# spec/requests/api/v1/following/sleep_records_spec.rb
path '/api/v1/following/sleep_records' do
  get('Get sleep records from followed users') do
    tags 'Social Sleep Data'
    description 'Retrieve sleep records from users that the current user follows'
    produces 'application/json'

    parameter name: 'X-USER-ID', in: :header, type: :string, required: true,
              description: 'User ID for authentication'

    response '200', 'Sleep records retrieved successfully' do
      description 'Returns completed sleep records from followed users'
      schema type: :object,
             properties: {
               sleep_records: {
                 type: :array,
                 items: {
                   type: :object,
                   properties: {
                     id: { type: :integer },
                     user_id: { type: :integer },
                     user_name: { type: :string },
                     bedtime: { type: :string, format: 'date-time' },
                     wake_time: { type: :string, format: 'date-time' },
                     duration_minutes: { type: :integer },
                     formatted_duration: { type: :string },
                     sleep_date: { type: :string, format: 'date' },
                     created_at: { type: :string, format: 'date-time' }
                   }
                 }
               },
               total_count: { type: :integer }
             }

      context 'with followed users having sleep records' do
        let!(:current_user) { User.create!(name: 'Social User') }
        let!(:followed_user1) { User.create!(name: 'Sleepy User 1') }
        let!(:followed_user2) { User.create!(name: 'Sleepy User 2') }
        let(:'X-USER-ID') { current_user.id.to_s }

        before do
          current_user.follows.create!(following_user: followed_user1)
          current_user.follows.create!(following_user: followed_user2)

          # Create completed sleep records
          followed_user1.sleep_records.create!(
            bedtime: 2.days.ago + 22.hours,
            wake_time: 1.day.ago + 7.hours,
            duration_minutes: 540
          )
          followed_user2.sleep_records.create!(
            bedtime: 1.day.ago + 23.hours,
            wake_time: Time.current + 8.hours,
            duration_minutes: 480
          )
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['sleep_records']).to be_an(Array)
          expect(data['sleep_records'].size).to eq(2)
          expect(data['total_count']).to eq(2)

          # Check record structure
          record = data['sleep_records'].first
          expect(record).to have_key('user_name')
          expect(record).to have_key('duration_minutes')
          expect(record).to have_key('formatted_duration')
        end
      end
    end

    response '400', 'Authentication required' do
      schema '$ref' => '#/components/schemas/Error'

      context 'without X-USER-ID header' do
        let(:'X-USER-ID') { nil }
        run_test!
      end
    end
  end
end
```

### Acceptance Criteria
- [ ] Endpoint returns sleep records only from followed users
- [ ] Only completed records (with both bedtime and wake_time) included
- [ ] Each record includes user identification (ID and name)
- [ ] Records include all essential sleep data (times, duration)
- [ ] Empty response handled gracefully with helpful message
- [ ] Requires authentication via X-USER-ID header

---

## Step 3: Date Range Filtering Implementation
**Goal**: Add filtering to limit sleep records to the last 7 days

### Tasks Checklist
- [ ] Add date filtering to social sleep records endpoint
- [ ] Implement query parameter for date range customization
- [ ] Add validation for date range parameters
- [ ] Update database queries to use date indexes efficiently
- [ ] Add date range information to API response

### Tests to Write First
**Use rswag for API documentation**

- [ ] rswag API specs for date filtering (extend existing spec file)
  - [ ] Default behavior (last 7 days) works correctly
  - [ ] Custom date range parameter works
  - [ ] Invalid date parameters handled gracefully
  - [ ] Records outside date range excluded
  - [ ] Date range metadata included in response

### Implementation Details
```ruby
# Update app/controllers/api/v1/following/sleep_records_controller.rb
class Api::V1::Following::SleepRecordsController < Api::V1::BaseController
  before_action :authenticate_user
  before_action :validate_date_params

  def index
    days_back = params[:days]&.to_i || 7

    sleep_records = SleepRecord.social_feed_for_user(current_user)
                               .recent_records(days_back)

    if sleep_records.empty?
      render_success({
        sleep_records: [],
        date_range: {
          days_back: days_back,
          from_date: days_back.days.ago.to_date.iso8601,
          to_date: Date.current.iso8601
        },
        message: "No sleep records found in the last #{days_back} days. Follow users to see their sleep data!"
      })
      return
    end

    records_data = sleep_records.map do |record|
      {
        id: record.id,
        user_id: record.user_id,
        user_name: record.user_name,
        bedtime: record.bedtime.iso8601,
        wake_time: record.wake_time.iso8601,
        duration_minutes: record.duration_minutes,
        formatted_duration: record.formatted_duration,
        sleep_date: record.sleep_date.iso8601,
        created_at: record.created_at.iso8601
      }
    end

    render_success({
      sleep_records: records_data,
      total_count: records_data.length,
      date_range: {
        days_back: days_back,
        from_date: days_back.days.ago.to_date.iso8601,
        to_date: Date.current.iso8601
      }
    })
  end

  private

  def validate_date_params
    if params[:days].present?
      days = params[:days].to_i
      if days < 1 || days > 30
        render_error(
          'Date range must be between 1 and 30 days',
          'INVALID_DATE_RANGE',
          { allowed_range: '1-30 days' },
          :bad_request
        )
        return
      end
    end
  end
end
```

### API Specification (rswag)
```ruby
# Update spec/requests/api/v1/following/sleep_records_spec.rb
parameter name: :days, in: :query, type: :integer, required: false,
          description: 'Number of days to look back (1-30, default 7)'

# Add response schema for date_range
date_range: {
  type: :object,
  properties: {
    days_back: { type: :integer },
    from_date: { type: :string, format: 'date' },
    to_date: { type: :string, format: 'date' }
  }
}

# Add test context for date filtering
context 'with custom date range' do
  let(:days) { 3 }

  run_test! do |response|
    data = JSON.parse(response.body)
    expect(data['date_range']['days_back']).to eq(3)
  end
end
```

### Acceptance Criteria
- [ ] Default behavior filters to last 7 days
- [ ] Custom date range parameter (1-30 days) works correctly
- [ ] Invalid date range parameters return clear error messages
- [ ] Date range metadata included in API response
- [ ] Database queries use date indexes efficiently
- [ ] Records outside specified date range excluded

---

## Step 4: Duration-Based Sorting & Aggregation
**Goal**: Implement sorting by sleep duration and handle multiple records per user

### Tasks Checklist
- [ ] Implement duration-based sorting (longest to shortest)
- [ ] Allow multiple records per user in results
- [ ] Add sorting options query parameter
- [ ] Implement aggregation statistics for the feed
- [ ] Add duration formatting and display helpers
- [ ] Optimize queries for large datasets

### Tests to Write First
**Use rswag for API documentation**

- [ ] rswag API specs for duration sorting (extend existing spec file)
  - [ ] Records sorted by duration (descending) by default
  - [ ] Multiple records per user included
  - [ ] Sorting parameter options work correctly
  - [ ] Duration formatting is consistent
  - [ ] Aggregation statistics calculated correctly

### Implementation Details
```ruby
# Update app/controllers/api/v1/following/sleep_records_controller.rb
class Api::V1::Following::SleepRecordsController < Api::V1::BaseController
  before_action :authenticate_user
  before_action :validate_date_params
  before_action :validate_sort_params

  def index
    days_back = params[:days]&.to_i || 7
    sort_by = params[:sort_by] || 'duration'

    sleep_records = SleepRecord.social_feed_for_user(current_user)
                               .recent_records(days_back)
                               .apply_sorting(sort_by)

    if sleep_records.empty?
      render_success({
        sleep_records: [],
        statistics: generate_empty_statistics,
        date_range: date_range_info(days_back),
        sorting: { sort_by: sort_by },
        message: "No sleep records found in the last #{days_back} days."
      })
      return
    end

    records_data = sleep_records.map do |record|
      {
        id: record.id,
        user_id: record.user_id,
        user_name: record.user_name,
        bedtime: record.bedtime.iso8601,
        wake_time: record.wake_time.iso8601,
        duration_minutes: record.duration_minutes,
        formatted_duration: record.formatted_duration,
        sleep_date: record.sleep_date.iso8601,
        created_at: record.created_at.iso8601
      }
    end

    statistics = generate_statistics(sleep_records)

    render_success({
      sleep_records: records_data,
      total_count: records_data.length,
      statistics: statistics,
      date_range: date_range_info(days_back),
      sorting: { sort_by: sort_by }
    })
  end

  private

  def validate_sort_params
    allowed_sorts = %w[duration bedtime wake_time created_at]
    if params[:sort_by].present? && !allowed_sorts.include?(params[:sort_by])
      render_error(
        'Invalid sort parameter',
        'INVALID_SORT_PARAMETER',
        { allowed_values: allowed_sorts },
        :bad_request
      )
    end
  end

  def generate_statistics(records)
    durations = records.pluck(:duration_minutes).compact
    return generate_empty_statistics if durations.empty?

    {
      total_records: records.count,
      unique_users: records.pluck(:user_id).uniq.count,
      duration_stats: {
        average_minutes: (durations.sum.to_f / durations.count).round,
        longest_minutes: durations.max,
        shortest_minutes: durations.min,
        total_sleep_hours: (durations.sum.to_f / 60).round(1)
      }
    }
  end

  def generate_empty_statistics
    {
      total_records: 0,
      unique_users: 0,
      duration_stats: {
        average_minutes: 0,
        longest_minutes: 0,
        shortest_minutes: 0,
        total_sleep_hours: 0
      }
    }
  end

  def date_range_info(days_back)
    {
      days_back: days_back,
      from_date: days_back.days.ago.to_date.iso8601,
      to_date: Date.current.iso8601
    }
  end
end
```

```ruby
# Update app/models/sleep_record.rb to add sorting scope
scope :apply_sorting, ->(sort_by) {
  case sort_by
  when 'duration'
    order(duration_minutes: :desc)
  when 'bedtime'
    order(bedtime: :desc)
  when 'wake_time'
    order(wake_time: :desc)
  when 'created_at'
    order(created_at: :desc)
  else
    order(duration_minutes: :desc) # Default
  end
}
```

### API Specification (rswag)
```ruby
# Update spec/requests/api/v1/following/sleep_records_spec.rb
parameter name: :sort_by, in: :query, type: :string, required: false,
          description: 'Sort field: duration, bedtime, wake_time, created_at (default: duration)'

# Add response schema for statistics
statistics: {
  type: :object,
  properties: {
    total_records: { type: :integer },
    unique_users: { type: :integer },
    duration_stats: {
      type: :object,
      properties: {
        average_minutes: { type: :integer },
        longest_minutes: { type: :integer },
        shortest_minutes: { type: :integer },
        total_sleep_hours: { type: :number }
      }
    }
  }
}
```

### Acceptance Criteria
- [ ] Records sorted by sleep duration (longest first) by default
- [ ] Multiple records per user allowed in results
- [ ] Alternative sorting options (bedtime, wake_time, created_at) work
- [ ] Aggregation statistics calculated correctly
- [ ] Duration formatting is consistent across responses
- [ ] Performance acceptable with multiple records per user

---

## Step 5: Complete Records Filter & Privacy Controls
**Goal**: Ensure only complete sleep records are shown and privacy controls are enforced

### Tasks Checklist
- [ ] Enforce complete records filter (both bedtime and wake_time required)
- [ ] Add privacy validation (only followed users' data)
- [ ] Implement user blocking/privacy preference support (future-ready)
- [ ] Add data visibility controls
- [ ] Create audit logging for social data access
- [ ] Add user identification and attribution

### Tests to Write First
**Use rswag and standard RSpec**

- [ ] rswag API specs for privacy controls (extend existing spec file)
  - [ ] Only complete records (bedtime + wake_time) included
  - [ ] Non-followed users' records excluded
  - [ ] Privacy controls respected
  - [ ] User identification accurate
- [ ] Privacy enforcement tests (standard RSpec)
  - [ ] Incomplete records filtered out
  - [ ] Unfollowed users' data not accessible
  - [ ] Current user's own records excluded from social feed

### Implementation Details
```ruby
# Update app/models/sleep_record.rb
class SleepRecord < ApplicationRecord
  # Enhanced scopes for privacy and completeness
  scope :completed_records, -> {
    where.not(bedtime: nil)
         .where.not(wake_time: nil)
         .where.not(duration_minutes: nil)
  }

  scope :for_social_feed, -> {
    completed_records.recent_records.by_duration
  }

  def self.social_feed_for_user(user)
    followed_user_ids = user.following_users.pluck(:id)
    return none if followed_user_ids.empty?

    # Explicitly exclude the requesting user's own records
    includes(:user)
      .where(user_id: followed_user_ids)
      .where.not(user_id: user.id)
      .for_social_feed
  end

  # Privacy and validation helpers
  def complete_record?
    bedtime.present? && wake_time.present? && duration_minutes.present?
  end

  def accessible_by?(requesting_user)
    return true if user_id == requesting_user.id
    requesting_user.following?(user)
  end
end
```

```ruby
# Update app/controllers/api/v1/following/sleep_records_controller.rb
class Api::V1::Following::SleepRecordsController < Api::V1::BaseController
  before_action :authenticate_user
  before_action :validate_date_params
  before_action :validate_sort_params

  def index
    days_back = params[:days]&.to_i || 7
    sort_by = params[:sort_by] || 'duration'

    # Enhanced query with explicit privacy controls
    sleep_records = SleepRecord.social_feed_for_user(current_user)
                               .recent_records(days_back)
                               .apply_sorting(sort_by)

    # Log access for audit purposes
    log_social_data_access(sleep_records.count)

    if sleep_records.empty?
      render_success({
        sleep_records: [],
        statistics: generate_empty_statistics,
        date_range: date_range_info(days_back),
        sorting: { sort_by: sort_by },
        privacy_info: privacy_info,
        message: determine_empty_message(days_back)
      })
      return
    end

    records_data = sleep_records.map do |record|
      {
        id: record.id,
        user_id: record.user_id,
        user_name: record.user_name,
        bedtime: record.bedtime.iso8601,
        wake_time: record.wake_time.iso8601,
        duration_minutes: record.duration_minutes,
        formatted_duration: record.formatted_duration,
        sleep_date: record.sleep_date.iso8601,
        created_at: record.created_at.iso8601,
        record_complete: record.complete_record?
      }
    end

    statistics = generate_statistics(sleep_records)

    render_success({
      sleep_records: records_data,
      total_count: records_data.length,
      statistics: statistics,
      date_range: date_range_info(days_back),
      sorting: { sort_by: sort_by },
      privacy_info: privacy_info
    })
  end

  private

  def log_social_data_access(record_count)
    Rails.logger.info "User #{current_user.id} accessed #{record_count} social sleep records"
  end

  def privacy_info
    {
      data_source: 'followed_users_only',
      record_types: 'completed_records_only',
      your_records_included: false,
      following_count: current_user.following_users.count
    }
  end

  def determine_empty_message(days_back)
    following_count = current_user.following_users.count

    if following_count == 0
      "You're not following anyone yet. Follow users to see their sleep data!"
    else
      "No completed sleep records found from the #{following_count} users you follow in the last #{days_back} days."
    end
  end
end
```

### API Specification (rswag)
```ruby
# Update spec/requests/api/v1/following/sleep_records_spec.rb
# Add response schema for privacy_info
privacy_info: {
  type: :object,
  properties: {
    data_source: { type: :string },
    record_types: { type: :string },
    your_records_included: { type: :boolean },
    following_count: { type: :integer }
  }
}

# Add test context for privacy controls
context 'privacy controls' do
  let!(:current_user) { User.create!(name: 'Privacy User') }
  let!(:followed_user) { User.create!(name: 'Followed User') }
  let!(:non_followed_user) { User.create!(name: 'Non-Followed User') }
  let(:'X-USER-ID') { current_user.id.to_s }

  before do
    current_user.follows.create!(following_user: followed_user)

    # Create complete record for followed user
    followed_user.sleep_records.create!(
      bedtime: 1.day.ago + 22.hours,
      wake_time: Time.current + 7.hours,
      duration_minutes: 540
    )

    # Create complete record for non-followed user (should be excluded)
    non_followed_user.sleep_records.create!(
      bedtime: 1.day.ago + 23.hours,
      wake_time: Time.current + 8.hours,
      duration_minutes: 480
    )

    # Create incomplete record for followed user (should be excluded)
    followed_user.sleep_records.create!(
      bedtime: 1.day.ago + 21.hours,
      wake_time: nil,
      duration_minutes: nil
    )
  end

  run_test! do |response|
    data = JSON.parse(response.body)
    expect(data['sleep_records'].size).to eq(1) # Only followed user's complete record
    expect(data['privacy_info']['following_count']).to eq(1)
    expect(data['privacy_info']['your_records_included']).to be(false)
  end
end
```

### Acceptance Criteria
- [ ] Only complete records (bedtime + wake_time + duration) included
- [ ] Only followed users' sleep records accessible
- [ ] Current user's own records excluded from social feed
- [ ] Privacy information included in API response
- [ ] Audit logging implemented for data access
- [ ] Clear messaging when no records meet privacy criteria

---

## Step 6: Pagination & Performance Optimization
**Goal**: Add pagination support and optimize queries for large datasets

### Tasks Checklist
- [ ] Implement pagination with limit/offset parameters
- [ ] Add pagination metadata to API responses
- [ ] Optimize database queries to prevent N+1 problems
- [ ] Add query performance monitoring
- [ ] Implement efficient counting for large datasets
- [ ] Add performance tests for large social networks

### Tests to Write First
**Use rswag and performance tests**

- [ ] rswag API specs for pagination (extend existing spec file)
  - [ ] Pagination parameters (limit, offset) work correctly
  - [ ] Pagination metadata accurate
  - [ ] Large datasets paginated efficiently
  - [ ] Pagination works with sorting and filtering
- [ ] Performance tests (standard RSpec)
  - [ ] Query performance with 1000+ sleep records
  - [ ] N+1 query prevention validation
  - [ ] Large social network scenarios (100+ followed users)

### Implementation Details
```ruby
# Update app/controllers/api/v1/following/sleep_records_controller.rb
class Api::V1::Following::SleepRecordsController < Api::V1::BaseController
  before_action :authenticate_user
  before_action :validate_date_params
  before_action :validate_sort_params
  before_action :validate_pagination_params

  def index
    days_back = params[:days]&.to_i || 7
    sort_by = params[:sort_by] || 'duration'
    limit = [params[:limit]&.to_i || 20, 100].min
    offset = params[:offset]&.to_i || 0

    # Base query with performance optimizations
    base_query = SleepRecord.social_feed_for_user(current_user)
                           .recent_records(days_back)
                           .apply_sorting(sort_by)

    # Get total count efficiently
    total_count = base_query.count

    # Get paginated results with includes to prevent N+1
    sleep_records = base_query.includes(:user)
                             .limit(limit)
                             .offset(offset)

    log_social_data_access(sleep_records.length, total_count)

    if sleep_records.empty?
      render_success({
        sleep_records: [],
        statistics: generate_empty_statistics,
        pagination: pagination_info(0, limit, offset, total_count),
        date_range: date_range_info(days_back),
        sorting: { sort_by: sort_by },
        privacy_info: privacy_info,
        message: determine_empty_message(days_back)
      })
      return
    end

    records_data = sleep_records.map do |record|
      {
        id: record.id,
        user_id: record.user_id,
        user_name: record.user_name, # No N+1 due to includes
        bedtime: record.bedtime.iso8601,
        wake_time: record.wake_time.iso8601,
        duration_minutes: record.duration_minutes,
        formatted_duration: record.formatted_duration,
        sleep_date: record.sleep_date.iso8601,
        created_at: record.created_at.iso8601
      }
    end

    # Generate statistics from full dataset, not just current page
    statistics = generate_statistics_from_base_query(base_query)

    render_success({
      sleep_records: records_data,
      pagination: pagination_info(records_data.length, limit, offset, total_count),
      statistics: statistics,
      date_range: date_range_info(days_back),
      sorting: { sort_by: sort_by },
      privacy_info: privacy_info
    })
  end

  private

  def validate_pagination_params
    if params[:limit].present?
      limit = params[:limit].to_i
      if limit < 1 || limit > 100
        render_error(
          'Limit must be between 1 and 100',
          'INVALID_PAGINATION_LIMIT',
          { allowed_range: '1-100' },
          :bad_request
        )
        return
      end
    end

    if params[:offset].present?
      offset = params[:offset].to_i
      if offset < 0
        render_error(
          'Offset must be non-negative',
          'INVALID_PAGINATION_OFFSET',
          {},
          :bad_request
        )
        return
      end
    end
  end

  def pagination_info(current_count, limit, offset, total_count)
    {
      total_count: total_count,
      current_count: current_count,
      limit: limit,
      offset: offset,
      has_more: (offset + limit) < total_count,
      next_offset: (offset + limit) < total_count ? (offset + limit) : nil,
      previous_offset: offset > 0 ? [offset - limit, 0].max : nil
    }
  end

  def generate_statistics_from_base_query(base_query)
    # Use database aggregation for efficiency
    stats = base_query.group(:user_id).group('DATE(bedtime)').count
    durations = base_query.pluck(:duration_minutes).compact

    return generate_empty_statistics if durations.empty?

    {
      total_records: durations.count,
      unique_users: base_query.distinct.count(:user_id),
      duration_stats: {
        average_minutes: (durations.sum.to_f / durations.count).round,
        longest_minutes: durations.max,
        shortest_minutes: durations.min,
        total_sleep_hours: (durations.sum.to_f / 60).round(1)
      }
    }
  end

  def log_social_data_access(returned_count, total_available)
    Rails.logger.info "User #{current_user.id} accessed #{returned_count}/#{total_available} social sleep records"
  end
end
```

### API Specification (rswag)
```ruby
# Update spec/requests/api/v1/following/sleep_records_spec.rb
parameter name: :limit, in: :query, type: :integer, required: false,
          description: 'Number of results per page (1-100, default 20)'
parameter name: :offset, in: :query, type: :integer, required: false,
          description: 'Starting position (default 0)'

# Add response schema for pagination
pagination: {
  type: :object,
  properties: {
    total_count: { type: :integer },
    current_count: { type: :integer },
    limit: { type: :integer },
    offset: { type: :integer },
    has_more: { type: :boolean },
    next_offset: { type: :integer, nullable: true },
    previous_offset: { type: :integer, nullable: true }
  }
}

# Add test context for pagination
context 'with pagination' do
  let(:limit) { 5 }
  let(:offset) { 0 }

  before do
    # Create 12 sleep records across multiple followed users
    3.times do |i|
      user = User.create!(name: "User #{i}")
      current_user.follows.create!(following_user: user)

      4.times do |j|
        user.sleep_records.create!(
          bedtime: (j + 1).days.ago + 22.hours,
          wake_time: (j + 1).days.ago + 30.hours,
          duration_minutes: 480 + (i * 60) + (j * 15)
        )
      end
    end
  end

  run_test! do |response|
    data = JSON.parse(response.body)
    expect(data['sleep_records'].size).to eq(5)
    expect(data['pagination']['total_count']).to eq(12)
    expect(data['pagination']['has_more']).to be(true)
    expect(data['pagination']['next_offset']).to eq(5)
  end
end
```

### Acceptance Criteria
- [ ] Pagination works correctly with limit/offset parameters
- [ ] Pagination metadata accurate and helpful
- [ ] Database queries optimized (no N+1 problems)
- [ ] Performance acceptable with large datasets (1000+ records)
- [ ] Statistics calculated from full dataset, not just current page
- [ ] Pagination works correctly with sorting and filtering

---

## Step 7: Integration Testing & Manual Validation
**Goal**: Comprehensive testing and manual validation of all social sleep data functionality

### Tasks Checklist
- [ ] Write comprehensive integration tests
- [ ] Manual testing with curl commands
- [ ] Verify privacy and security controls
- [ ] Test performance with large datasets
- [ ] Test edge cases and error scenarios
- [ ] Update API documentation generation

### Tests to Write First
**Integration and performance tests**

- [ ] Integration tests for complete social sleep data workflows
  - [ ] User follows others, sees their completed sleep records
  - [ ] Date filtering works across multiple users' records
  - [ ] Duration sorting and aggregation across social network
  - [ ] Pagination across large social sleep datasets
  - [ ] Privacy controls prevent unauthorized access
- [ ] Performance tests
  - [ ] Social feed generation with 100+ followed users
  - [ ] Pagination performance with 1000+ sleep records
  - [ ] Query performance monitoring and optimization
- [ ] Edge case tests
  - [ ] Empty social networks (no followed users)
  - [ ] Users with no completed sleep records
  - [ ] Large date ranges with sparse data
  - [ ] Concurrent access to social sleep data

### Manual Testing Commands
```bash
# Setup: Create users and relationships
curl -X POST http://localhost:3000/api/v1/users \
  -H "Content-Type: application/json" \
  -d '{"name": "Social User"}'

curl -X POST http://localhost:3000/api/v1/users \
  -H "Content-Type: application/json" \
  -d '{"name": "Sleeper 1"}'

curl -X POST http://localhost:3000/api/v1/users \
  -H "Content-Type: application/json" \
  -d '{"name": "Sleeper 2"}'

# Setup following relationships (assuming Social User=1, Sleeper 1=2, Sleeper 2=3)
curl -X POST http://localhost:3000/api/v1/follows \
  -H "Content-Type: application/json" \
  -H "X-USER-ID: 1" \
  -d '{"following_user_id": 2}'

curl -X POST http://localhost:3000/api/v1/follows \
  -H "Content-Type: application/json" \
  -H "X-USER-ID: 1" \
  -d '{"following_user_id": 3}'

# Create sleep records for followed users
# Sleeper 1 - complete record
curl -X POST http://localhost:3000/api/v1/sleep_records \
  -H "Content-Type: application/json" \
  -H "X-USER-ID: 2" \
  -d '{"bedtime": "2024-12-20T22:00:00Z"}'

# Get the sleep record ID from response, then clock out
curl -X PATCH http://localhost:3000/api/v1/sleep_records/[RECORD_ID] \
  -H "Content-Type: application/json" \
  -H "X-USER-ID: 2" \
  -d '{"wake_time": "2024-12-21T07:30:00Z"}'

# Sleeper 2 - complete record
curl -X POST http://localhost:3000/api/v1/sleep_records \
  -H "Content-Type: application/json" \
  -H "X-USER-ID: 3" \
  -d '{"bedtime": "2024-12-20T23:00:00Z"}'

curl -X PATCH http://localhost:3000/api/v1/sleep_records/[RECORD_ID] \
  -H "Content-Type: application/json" \
  -H "X-USER-ID: 3" \
  -d '{"wake_time": "2024-12-21T08:00:00Z"}'

# Test social sleep data endpoint
# Basic retrieval
curl -H "X-USER-ID: 1" http://localhost:3000/api/v1/following/sleep_records

# With date filtering
curl -H "X-USER-ID: 1" http://localhost:3000/api/v1/following/sleep_records?days=3

# With custom sorting
curl -H "X-USER-ID: 1" http://localhost:3000/api/v1/following/sleep_records?sort_by=bedtime

# With pagination
curl -H "X-USER-ID: 1" http://localhost:3000/api/v1/following/sleep_records?limit=5&offset=0

# Test error cases
# No authentication
curl http://localhost:3000/api/v1/following/sleep_records

# Invalid date range
curl -H "X-USER-ID: 1" http://localhost:3000/api/v1/following/sleep_records?days=50

# Invalid sort parameter
curl -H "X-USER-ID: 1" http://localhost:3000/api/v1/following/sleep_records?sort_by=invalid

# Test privacy: User trying to access their own records in social feed (should be empty)
curl -H "X-USER-ID: 2" http://localhost:3000/api/v1/following/sleep_records

# User with no following relationships
curl -H "X-USER-ID: 2" http://localhost:3000/api/v1/following/sleep_records
```

### API Documentation Generation
```bash
# Generate updated API documentation after all changes
docker-compose exec web bundle exec rake api_docs:update

# Verify swagger UI shows new social endpoints
# Visit: http://localhost:3000/api-docs
```

### Acceptance Criteria
- [ ] All unit tests pass with >90% coverage
- [ ] All integration tests pass
- [ ] All rswag API specs generate correct documentation
- [ ] Manual testing scenarios work as expected
- [ ] Privacy controls verified and secure
- [ ] Performance acceptable for expected social network sizes
- [ ] API documentation complete and accurate

---

## Phase Completion Checklist

### Technical Completeness
- [ ] All 7 steps completed with acceptance criteria met
- [ ] Social sleep data endpoint fully functional
- [ ] Date range filtering implemented and working
- [ ] Duration-based sorting and aggregation working
- [ ] Privacy controls properly enforced
- [ ] Pagination optimized for performance
- [ ] Database queries optimized and indexed

### Quality Gates
- [ ] Code coverage > 90%
- [ ] All rswag specs generate valid OpenAPI documentation
- [ ] Manual testing scenarios validated
- [ ] Performance acceptable for 100+ followed users
- [ ] Security and privacy controls verified
- [ ] No N+1 query problems

### Documentation
- [ ] API documentation updated and accurate
- [ ] High-level plan updated with Phase 4 completion
- [ ] Code comments where necessary
- [ ] Privacy and security considerations documented

### Preparation for Phase 5
- [ ] Performance bottlenecks identified for optimization
- [ ] Database query patterns ready for indexing strategy
- [ ] Caching opportunities identified
- [ ] Scalability concerns documented

---

## Success Metrics

### Functional Success
- Users can view sleep records from users they follow
- Date range filtering works correctly (last 7 days default)
- Records sorted by duration (longest to shortest)
- Only complete sleep records included
- Privacy controls prevent unauthorized access
- Pagination supports large social networks

### Technical Success
- API endpoints properly documented with OpenAPI
- Test coverage exceeds 90%
- Performance acceptable for social network scale
- Database queries optimized for social data access
- Privacy and security requirements met

### Preparation Success
- Foundation ready for Phase 5 performance optimization
- Caching strategies identified for social data
- Database indexing optimized for social queries
- API design supports future social features

### User Experience Success
- Meaningful aggregation statistics provided
- Clear messaging for empty states
- Helpful error messages for invalid requests
- Responsive performance for social data browsing