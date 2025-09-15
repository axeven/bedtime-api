# Phase 3 Detailed Plan - Social Following System

## Overview
This document provides a detailed implementation plan for Phase 3 of the Bedtime API. The goal is to implement user-to-user following relationships that will enable social features for sleep data sharing, using Test-Driven Development with rswag integration.

**Note**: This plan integrates the established rswag-based TDD approach. All API endpoints should be documented using rswag specs which automatically generate OpenAPI documentation. Authentication helpers and patterns are available in `spec/support/` directory.

## Phase Status: ✅ COMPLETED (6/6 steps completed)

### Progress Summary
- ✅ **Step 1**: Follow Model & Database Schema - **COMPLETED**
- ✅ **Step 2**: Follow User API Endpoint - **COMPLETED**
- ✅ **Step 3**: Unfollow User API Endpoint - **COMPLETED**
- ✅ **Step 4**: Following List Retrieval Endpoint - **COMPLETED**
- ✅ **Step 5**: Followers List Retrieval Endpoint - **COMPLETED**
- ✅ **Step 6**: Integration Testing & Manual Validation - **COMPLETED**

---

## Step 1: Follow Model & Database Schema
**Goal**: Create Follow model for user relationships with proper associations and constraints

### Tasks Checklist
- [x] Generate Follow model with proper columns
- [x] Create database migration with foreign keys and indexes
- [x] Add model validations and uniqueness constraints
- [x] Set up User associations (has_many follows, followers)
- [x] Add model scopes for following/followers queries
- [x] Run database migration and verify schema

### Tests to Write First
**Note**: Use rswag specs for API documentation - create templates in `spec/support/follow_schemas.rb`

- [x] Follow model validation tests (standard RSpec)
  - [x] User (follower) presence validation
  - [x] Following user presence validation
  - [x] Prevent self-following
  - [x] Prevent duplicate follow relationships
  - [x] Unique constraint on [user_id, following_user_id]
- [x] Follow model association tests (standard RSpec)
  - [x] Belongs to user (follower)
  - [x] Belongs to following_user (followed user)
  - [x] User has many follows relationship
  - [x] User has many followers relationship
- [x] Follow model scope tests (standard RSpec)
  - [x] Following list for specific user
  - [x] Followers list for specific user

### Implementation Details
```ruby
# app/models/follow.rb
class Follow < ApplicationRecord
  belongs_to :user # The person doing the following
  belongs_to :following_user, class_name: 'User'

  validates :user, presence: true
  validates :following_user, presence: true
  validates :user_id, uniqueness: { scope: :following_user_id }
  validate :cannot_follow_self

  scope :for_user, ->(user) { where(user: user) }
  scope :followers_of, ->(user) { where(following_user: user) }

  private

  def cannot_follow_self
    errors.add(:following_user, "cannot follow yourself") if user_id == following_user_id
  end
end
```

```ruby
# Update app/models/user.rb
class User < ApplicationRecord
  has_many :sleep_records, dependent: :destroy

  # Following relationships
  has_many :follows, dependent: :destroy
  has_many :following_users, through: :follows, source: :following_user

  # Follower relationships (reverse)
  has_many :follower_relationships, class_name: 'Follow', foreign_key: 'following_user_id', dependent: :destroy
  has_many :followers, through: :follower_relationships, source: :user

  # Convenience methods
  def following?(user)
    follows.exists?(following_user: user)
  end

  def followers_count
    follower_relationships.count
  end

  def following_count
    follows.count
  end
end
```

```bash
# Migration command
docker-compose exec web bundle exec rails generate model Follow user:references following_user:references
```

### Database Migration
```ruby
class CreateFollows < ActiveRecord::Migration[8.0]
  def change
    create_table :follows do |t|
      t.references :user, null: false, foreign_key: true
      t.references :following_user, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :follows, [:user_id, :following_user_id], unique: true
    add_index :follows, :following_user_id
  end
end
```

### Acceptance Criteria
- [x] Follow model prevents self-following
- [x] Follow model prevents duplicate relationships
- [x] User model has proper associations to follows and followers
- [x] Database constraints enforce uniqueness
- [x] Model includes convenience methods for checking relationships

---

## Step 2: Follow User API Endpoint
**Goal**: Implement API endpoint for users to follow other users

### Tasks Checklist
- [x] Create follows_controller.rb
- [x] Implement POST /api/v1/follows endpoint
- [x] Add proper authentication and authorization
- [x] Handle error cases (non-existent users, self-following, duplicates)
- [x] Return appropriate JSON responses
- [x] Add to API routes

### Tests to Write First
**Use rswag for API documentation**

- [x] rswag API specs for follows creation (in `spec/requests/api/v1/follows_spec.rb`)
  - [x] Successful follow creation (201)
  - [x] Authentication required (400)
  - [x] Following non-existent user (404)
  - [x] Attempting to follow self (422)
  - [x] Duplicate follow attempt (422)
  - [x] Invalid request format (400)

### Implementation Details
```ruby
# config/routes.rb - add to api/v1 namespace
resources :follows, only: [:create, :index, :destroy]
```

```ruby
# app/controllers/api/v1/follows_controller.rb
class Api::V1::FollowsController < ApplicationController
  before_action :authenticate_user!

  def create
    following_user = User.find_by(id: follow_params[:following_user_id])

    unless following_user
      render json: {
        error: 'User not found',
        error_code: 'USER_NOT_FOUND'
      }, status: :not_found
      return
    end

    if current_user.id == following_user.id
      render json: {
        error: 'Cannot follow yourself',
        error_code: 'SELF_FOLLOW_NOT_ALLOWED'
      }, status: :unprocessable_entity
      return
    end

    follow = current_user.follows.build(following_user: following_user)

    if follow.save
      render json: {
        id: follow.id,
        following_user_id: follow.following_user_id,
        following_user_name: following_user.name,
        created_at: follow.created_at.iso8601
      }, status: :created
    else
      if follow.errors[:user_id]&.include?('has already been taken')
        render json: {
          error: 'Already following this user',
          error_code: 'DUPLICATE_FOLLOW'
        }, status: :unprocessable_entity
      else
        render json: {
          error: 'Failed to create follow relationship',
          errors: follow.errors.full_messages,
          error_code: 'VALIDATION_ERROR'
        }, status: :unprocessable_entity
      end
    end
  end

  private

  def follow_params
    params.permit(:following_user_id)
  end
end
```

### API Specification (rswag)
```ruby
# Add to spec/requests/api/v1/follows_spec.rb
post '/api/v1/follows' do
  tags 'Follows'
  summary 'Follow a user'
  description 'Create a new following relationship with another user'

  parameter name: 'X-USER-ID', in: :header, type: :string, required: true,
            description: 'User ID for authentication'
  parameter name: :body, in: :body, schema: {
    type: :object,
    properties: {
      following_user_id: { type: :integer, description: 'ID of user to follow' }
    },
    required: ['following_user_id']
  }

  response '201', 'Follow created successfully' do
    schema type: :object,
           properties: {
             id: { type: :integer },
             following_user_id: { type: :integer },
             following_user_name: { type: :string },
             created_at: { type: :string, format: 'date-time' }
           }
  end

  response '404', 'User not found' do
    schema '$ref' => '#/components/schemas/ErrorResponse'
  end

  response '422', 'Cannot follow self or duplicate follow' do
    schema '$ref' => '#/components/schemas/ErrorResponse'
  end
end
```

### Acceptance Criteria
- [x] Users can follow other users by ID
- [x] Prevents self-following with clear error message
- [x] Prevents duplicate follows with appropriate response
- [x] Returns 404 for non-existent users
- [x] Returns proper JSON structure on success
- [x] Requires authentication via X-USER-ID header

---

## Step 3: Unfollow User API Endpoint
**Goal**: Implement API endpoint for users to unfollow other users

### Tasks Checklist
- [x] Implement DELETE /api/v1/follows/:following_user_id endpoint
- [x] Add proper authentication and authorization
- [x] Handle error cases (non-existent relationships)
- [x] Return appropriate status codes
- [x] Use following_user_id as identifier in URL

### Tests to Write First
**Use rswag for API documentation**

- [x] rswag API specs for unfollow (in `spec/requests/api/v1/follows_spec.rb`)
  - [x] Successful unfollow (204 No Content)
  - [x] Authentication required (400)
  - [x] Unfollowing non-existent user (404)
  - [x] Unfollowing user not being followed (404)

### Implementation Details
```ruby
# app/controllers/api/v1/follows_controller.rb - add destroy method
def destroy
  following_user = User.find_by(id: params[:id])

  unless following_user
    render json: {
      error: 'User not found',
      error_code: 'USER_NOT_FOUND'
    }, status: :not_found
    return
  end

  follow = current_user.follows.find_by(following_user: following_user)

  unless follow
    render json: {
      error: 'Not following this user',
      error_code: 'FOLLOW_RELATIONSHIP_NOT_FOUND'
    }, status: :not_found
    return
  end

  follow.destroy
  head :no_content
end
```

### API Specification (rswag)
```ruby
delete '/api/v1/follows/{following_user_id}' do
  tags 'Follows'
  summary 'Unfollow a user'
  description 'Remove a following relationship with another user'

  parameter name: 'X-USER-ID', in: :header, type: :string, required: true
  parameter name: :following_user_id, in: :path, type: :integer, required: true

  response '204', 'Successfully unfollowed user'
  response '404', 'User not found or not following' do
    schema '$ref' => '#/components/schemas/ErrorResponse'
  end
end
```

### Acceptance Criteria
- [x] Users can unfollow users they're following
- [x] Returns 204 No Content on successful unfollow
- [x] Returns 404 for non-existent users
- [x] Returns 404 for relationships that don't exist
- [x] Requires authentication via X-USER-ID header

---

## Step 4: Following List Retrieval Endpoint
**Goal**: Implement API endpoint to retrieve list of users that current user is following

### Tasks Checklist
- [x] Implement GET /api/v1/follows endpoint
- [x] Add pagination support (limit/offset)
- [x] Return user information for followed users
- [x] Add proper ordering (most recent follows first)
- [x] Include total count for pagination

### Tests to Write First
**Use rswag for API documentation**

- [x] rswag API specs for following list (in `spec/requests/api/v1/follows_spec.rb`)
  - [x] Successful retrieval with results (200)
  - [x] Empty results for user with no follows (200)
  - [x] Pagination parameters work correctly
  - [x] Authentication required (400)
  - [x] Proper ordering (newest follows first)

### Implementation Details
```ruby
# app/controllers/api/v1/follows_controller.rb - add index method
def index
  limit = [params[:limit]&.to_i || 20, 100].min
  offset = params[:offset]&.to_i || 0

  follows = current_user.follows
                       .includes(:following_user)
                       .order(created_at: :desc)
                       .limit(limit)
                       .offset(offset)

  total_count = current_user.follows.count

  following_users = follows.map do |follow|
    {
      id: follow.following_user.id,
      name: follow.following_user.name,
      followed_at: follow.created_at.iso8601
    }
  end

  render json: {
    following: following_users,
    pagination: {
      total_count: total_count,
      limit: limit,
      offset: offset,
      has_more: (offset + limit) < total_count
    }
  }
end
```

### API Specification (rswag)
```ruby
get '/api/v1/follows' do
  tags 'Follows'
  summary 'Get following list'
  description 'Retrieve list of users that the current user is following'

  parameter name: 'X-USER-ID', in: :header, type: :string, required: true
  parameter name: :limit, in: :query, type: :integer, required: false,
            description: 'Number of results (max 100, default 20)'
  parameter name: :offset, in: :query, type: :integer, required: false,
            description: 'Starting position (default 0)'

  response '200', 'Following list retrieved successfully' do
    schema type: :object,
           properties: {
             following: {
               type: :array,
               items: {
                 type: :object,
                 properties: {
                   id: { type: :integer },
                   name: { type: :string },
                   followed_at: { type: :string, format: 'date-time' }
                 }
               }
             },
             pagination: { '$ref' => '#/components/schemas/PaginationInfo' }
           }
  end
end
```

### Acceptance Criteria
- [x] Returns list of users current user is following
- [x] Includes user ID, name, and follow timestamp
- [x] Orders results by most recent follows first
- [x] Supports pagination with limit/offset
- [x] Returns pagination metadata
- [x] Requires authentication via X-USER-ID header

---

## Step 5: Followers List Retrieval Endpoint
**Goal**: Implement API endpoint to retrieve list of users following the current user

### Tasks Checklist
- [x] Create followers_controller.rb or add to follows_controller
- [x] Implement GET /api/v1/followers endpoint
- [x] Add pagination support (limit/offset)
- [x] Return user information for followers
- [x] Add proper ordering (most recent followers first)
- [x] Include total count for pagination

### Tests to Write First
**Use rswag for API documentation**

- [x] rswag API specs for followers list (in `spec/requests/api/v1/followers_spec.rb`)
  - [x] Successful retrieval with results (200)
  - [x] Empty results for user with no followers (200)
  - [x] Pagination parameters work correctly
  - [x] Authentication required (400)
  - [x] Proper ordering (newest followers first)

### Implementation Details
```ruby
# Option 1: Add to follows_controller.rb or create separate followers_controller.rb
# config/routes.rb - add to api/v1 namespace
resources :followers, only: [:index]

# app/controllers/api/v1/followers_controller.rb
class Api::V1::FollowersController < ApplicationController
  before_action :authenticate_user!

  def index
    limit = [params[:limit]&.to_i || 20, 100].min
    offset = params[:offset]&.to_i || 0

    follower_relationships = current_user.follower_relationships
                                        .includes(:user)
                                        .order(created_at: :desc)
                                        .limit(limit)
                                        .offset(offset)

    total_count = current_user.follower_relationships.count

    followers = follower_relationships.map do |follow|
      {
        id: follow.user.id,
        name: follow.user.name,
        followed_at: follow.created_at.iso8601
      }
    end

    render json: {
      followers: followers,
      pagination: {
        total_count: total_count,
        limit: limit,
        offset: offset,
        has_more: (offset + limit) < total_count
      }
    }
  end
end
```

### API Specification (rswag)
```ruby
# spec/requests/api/v1/followers_spec.rb
get '/api/v1/followers' do
  tags 'Followers'
  summary 'Get followers list'
  description 'Retrieve list of users following the current user'

  parameter name: 'X-USER-ID', in: :header, type: :string, required: true
  parameter name: :limit, in: :query, type: :integer, required: false
  parameter name: :offset, in: :query, type: :integer, required: false

  response '200', 'Followers list retrieved successfully' do
    schema type: :object,
           properties: {
             followers: {
               type: :array,
               items: {
                 type: :object,
                 properties: {
                   id: { type: :integer },
                   name: { type: :string },
                   followed_at: { type: :string, format: 'date-time' }
                 }
               }
             },
             pagination: { '$ref' => '#/components/schemas/PaginationInfo' }
           }
  end
end
```

### Acceptance Criteria
- [x] Returns list of users following the current user
- [x] Includes user ID, name, and follow timestamp
- [x] Orders results by most recent followers first
- [x] Supports pagination with limit/offset
- [x] Returns pagination metadata
- [x] Requires authentication via X-USER-ID header

---

## Step 6: Integration Testing & Manual Validation
**Goal**: Comprehensive testing and manual validation of all following system functionality

### Tasks Checklist
- [x] Write comprehensive integration tests
- [x] Manual testing with curl commands
- [x] Verify error handling and edge cases
- [x] Test concurrent follow/unfollow operations
- [x] Performance testing with multiple relationships
- [x] Update API documentation generation

### Tests to Write First
**Integration and performance tests**

- [x] Integration tests for complete follow/unfollow workflows
  - [x] User A follows User B, both can see in their respective lists
  - [x] User A unfollows User B, relationship removed from both lists
  - [x] Multiple users following same user (fan-out scenarios)
  - [x] Single user following multiple users (fan-in scenarios)
- [x] Performance tests (basic)
  - [x] Following list retrieval with 100+ relationships
  - [x] Followers list retrieval with 100+ relationships
  - [x] Follow creation under concurrent load
- [x] Edge case tests
  - [x] Following/unfollowing deleted users
  - [x] Database consistency during failures
  - [x] Pagination boundary conditions

### Manual Testing Commands
```bash
# Create test users
curl -X POST http://localhost:3000/api/v1/users \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice"}'

curl -X POST http://localhost:3000/api/v1/users \
  -H "Content-Type: application/json" \
  -d '{"name": "Bob"}'

curl -X POST http://localhost:3000/api/v1/users \
  -H "Content-Type: application/json" \
  -d '{"name": "Charlie"}'

# Alice follows Bob (assuming Alice=1, Bob=2)
curl -X POST http://localhost:3000/api/v1/follows \
  -H "Content-Type: application/json" \
  -H "X-USER-ID: 1" \
  -d '{"following_user_id": 2}'

# Alice's following list
curl -H "X-USER-ID: 1" http://localhost:3000/api/v1/follows

# Bob's followers list
curl -H "X-USER-ID: 2" http://localhost:3000/api/v1/followers

# Alice unfollows Bob
curl -X DELETE http://localhost:3000/api/v1/follows/2 \
  -H "X-USER-ID: 1"

# Test error cases
curl -X POST http://localhost:3000/api/v1/follows \
  -H "Content-Type: application/json" \
  -H "X-USER-ID: 1" \
  -d '{"following_user_id": 1}'  # Self-follow (should fail)

curl -X POST http://localhost:3000/api/v1/follows \
  -H "Content-Type: application/json" \
  -H "X-USER-ID: 1" \
  -d '{"following_user_id": 999}'  # Non-existent user (should fail)
```

### API Documentation Generation
```bash
# Generate updated API documentation after all changes
docker-compose exec web bundle exec rake api_docs:update

# Verify swagger UI shows new endpoints
# Visit: http://localhost:3000/api-docs
```

### Acceptance Criteria
- [x] All unit tests pass with >90% coverage
- [x] All integration tests pass
- [x] All rswag API specs generate correct documentation
- [x] Manual testing scenarios work as expected
- [x] Error handling is robust and user-friendly
- [x] Performance is acceptable for expected load
- [x] API documentation is complete and accurate

---

## Phase Completion Checklist

### Technical Completeness
- [x] All 6 steps completed with acceptance criteria met
- [x] Database schema properly designed with indexes
- [x] API endpoints follow RESTful conventions
- [x] Authentication and authorization properly implemented
- [x] Error handling comprehensive and consistent
- [x] All tests pass (unit, integration, API specs)

### Quality Gates
- [x] Code coverage > 90%
- [x] All rswag specs generate valid OpenAPI documentation
- [x] Manual testing scenarios validated
- [x] Performance acceptable for expected usage
- [x] Security considerations addressed (no unauthorized access)

### Documentation
- [x] API documentation updated and accurate
- [x] High-level plan updated with Phase 3 completion
- [x] Code comments where necessary
- [x] README updated if needed

### Preparation for Phase 4
- [x] Follow relationships ready for social sleep data queries
- [x] User model associations support efficient queries
- [x] Database indexes optimized for Phase 4 requirements
- [x] Error handling patterns established for social features

---

## Success Metrics

### Functional Success
- Users can follow and unfollow other users
- Following/followers lists work correctly with pagination
- All error cases handled gracefully
- Database relationships maintain integrity

### Technical Success
- API endpoints properly documented with OpenAPI
- Test coverage exceeds 90%
- Performance acceptable for initial scale
- Code quality meets established standards

### Preparation Success
- Foundation ready for Phase 4 social sleep data features
- Authentication patterns established and working
- Database design supports social queries efficiently
- API design consistent with overall system architecture