# Initial API Design - Bedtime Tracking API

## Overview
RESTful API design for a sleep tracking application built with Ruby on Rails. The API supports sleep record management, social following features, and viewing friends' sleep patterns.

## Base URL
```
/api/v1
```

## Authentication
- User identification is handled via `X-USER-ID` HTTP header
- All API requests must include `X-USER-ID` header with valid user ID
- No session/token management required for this implementation
- No registration endpoints required per specifications

**Required Header:**
```
X-USER-ID: 1
```

**Missing Header Response (400 Bad Request):**
```json
{
  "error": "X-USER-ID header is required",
  "error_code": "MISSING_USER_ID"
}
```

**Invalid User ID Response (404 Not Found):**
```json
{
  "error": "User not found",
  "error_code": "USER_NOT_FOUND"
}
```

---

## 0. Testing APIs (Development Only)

### 0.1 Create User (Testing Only)
**POST** `/api/v1/users`

Creates a new user for testing purposes. This endpoint should only be available in development/test environments.

**Headers:**
```
Content-Type: application/json
```

**Request Body:**
```json
{
  "name": "John Doe"
}
```

**Response (201 Created):**
```json
{
  "id": 15,
  "name": "John Doe",
  "created_at": "2023-12-07T10:30:00Z"
}
```

**Response (422 Unprocessable Entity):**
```json
{
  "error": "Validation failed",
  "error_code": "VALIDATION_ERROR",
  "details": {
    "name": ["can't be blank"]
  }
}
```

**Note:** This endpoint is intended for testing purposes only and should not be available in production environments. It allows creating test users without implementing a full registration system.

---

## 1. Sleep Records API

### 1.1 Clock In (Start Sleep Session)
**POST** `/api/v1/sleep_records`

Creates a new sleep record with bedtime timestamp.

**Headers:**
```
X-USER-ID: 1
Content-Type: application/json
```

**Request Body:**
```json
{
  "action": "clock_in"
}
```

**Response (201 Created):**
```json
{
  "id": 123,
  "user_id": 1,
  "bedtime": "2023-12-07T22:30:00Z",
  "wake_time": null,
  "duration_minutes": null,
  "created_at": "2023-12-07T22:30:00Z",
  "updated_at": "2023-12-07T22:30:00Z"
}
```

### 1.2 Clock Out (End Sleep Session)
**PATCH/PUT** `/api/v1/sleep_records/:id`

Updates existing sleep record with wake-up time and calculates duration.

**Headers:**
```
X-USER-ID: 1
Content-Type: application/json
```

**Request Body:**
```json
{
  "action": "clock_out"
}
```

**Response (200 OK):**
```json
{
  "id": 123,
  "user_id": 1,
  "bedtime": "2023-12-07T22:30:00Z",
  "wake_time": "2023-12-08T07:15:00Z",
  "duration_minutes": 525,
  "created_at": "2023-12-07T22:30:00Z",
  "updated_at": "2023-12-08T07:15:00Z"
}
```

### 1.3 Get User's Sleep Records
**GET** `/api/v1/sleep_records`

Returns all sleep records for the authenticated user, ordered by creation time.

**Headers:**
```
X-USER-ID: 1
```

**Query Parameters:**
- `page` (optional): Page number for pagination (default: 1)
- `per_page` (optional): Records per page (default: 20, max: 100)
- `status` (optional): Filter by 'complete' or 'incomplete' records

**Response (200 OK):**
```json
{
  "sleep_records": [
    {
      "id": 124,
      "user_id": 1,
      "bedtime": "2023-12-08T23:00:00Z",
      "wake_time": "2023-12-09T07:30:00Z",
      "duration_minutes": 510,
      "created_at": "2023-12-08T23:00:00Z",
      "updated_at": "2023-12-09T07:30:00Z"
    },
    {
      "id": 123,
      "user_id": 1,
      "bedtime": "2023-12-07T22:30:00Z",
      "wake_time": "2023-12-08T07:15:00Z",
      "duration_minutes": 525,
      "created_at": "2023-12-07T22:30:00Z",
      "updated_at": "2023-12-08T07:15:00Z"
    }
  ],
  "pagination": {
    "current_page": 1,
    "total_pages": 3,
    "total_count": 45,
    "per_page": 20
  }
}
```

### 1.4 Get Current Active Sleep Session
**GET** `/api/v1/sleep_records/current`

Returns the current incomplete sleep record (clocked in but not clocked out).

**Headers:**
```
X-USER-ID: 1
```

**Response (200 OK):**
```json
{
  "id": 125,
  "user_id": 1,
  "bedtime": "2023-12-09T22:45:00Z",
  "wake_time": null,
  "duration_minutes": null,
  "created_at": "2023-12-09T22:45:00Z",
  "updated_at": "2023-12-09T22:45:00Z"
}
```

**Response (404 Not Found):**
```json
{
  "error": "No active sleep session found"
}
```

---

## 2. Following/Social API

### 2.1 Follow a User
**POST** `/api/v1/follows`

Creates a following relationship between current user and target user.

**Headers:**
```
X-USER-ID: 1
Content-Type: application/json
```

**Request Body:**
```json
{
  "following_id": 5
}
```

**Response (201 Created):**
```json
{
  "id": 78,
  "follower_id": 1,
  "following_id": 5,
  "created_at": "2023-12-07T10:30:00Z"
}
```

**Response (409 Conflict):**
```json
{
  "error": "Already following this user"
}
```

### 2.2 Unfollow a User
**DELETE** `/api/v1/follows/:following_id`

Removes following relationship with specified user.

**Headers:**
```
X-USER-ID: 1
```

**Response (204 No Content)**

**Response (404 Not Found):**
```json
{
  "error": "Following relationship not found"
}
```

### 2.3 Get Following List
**GET** `/api/v1/follows`

Returns list of users that current user is following.

**Headers:**
```
X-USER-ID: 1
```

**Query Parameters:**
- `page` (optional): Page number for pagination
- `per_page` (optional): Results per page

**Response (200 OK):**
```json
{
  "following": [
    {
      "id": 5,
      "name": "Alice Johnson",
      "followed_at": "2023-12-07T10:30:00Z"
    },
    {
      "id": 8,
      "name": "Bob Smith",
      "followed_at": "2023-12-06T14:20:00Z"
    }
  ],
  "pagination": {
    "current_page": 1,
    "total_pages": 1,
    "total_count": 2,
    "per_page": 20
  }
}
```

### 2.4 Get Followers List
**GET** `/api/v1/followers`

Returns list of users following the current user.

**Headers:**
```
X-USER-ID: 1
```

**Response (200 OK):**
```json
{
  "followers": [
    {
      "id": 12,
      "name": "Charlie Brown",
      "followed_at": "2023-12-05T16:45:00Z"
    }
  ],
  "pagination": {
    "current_page": 1,
    "total_pages": 1,
    "total_count": 1,
    "per_page": 20
  }
}
```

---

## 3. Following Users' Sleep Records API

### 3.1 Get Following Users' Sleep Records (Previous Week)
**GET** `/api/v1/following/sleep_records`

Returns sleep records from all followed users for the previous week, sorted by duration.

**Headers:**
```
X-USER-ID: 1
```

**Query Parameters:**
- `page` (optional): Page number for pagination
- `per_page` (optional): Results per page
- `days` (optional): Number of days to look back (default: 7, max: 30)

**Response (200 OK):**
```json
{
  "sleep_records": [
    {
      "id": 456,
      "user": {
        "id": 5,
        "name": "Alice Johnson"
      },
      "bedtime": "2023-12-06T21:00:00Z",
      "wake_time": "2023-12-07T08:30:00Z",
      "duration_minutes": 690,
      "created_at": "2023-12-06T21:00:00Z"
    },
    {
      "id": 789,
      "user": {
        "id": 8,
        "name": "Bob Smith"
      },
      "bedtime": "2023-12-05T23:30:00Z",
      "wake_time": "2023-12-06T07:45:00Z",
      "duration_minutes": 495,
      "created_at": "2023-12-05T23:30:00Z"
    },
    {
      "id": 457,
      "user": {
        "id": 5,
        "name": "Alice Johnson"
      },
      "bedtime": "2023-12-04T22:15:00Z",
      "wake_time": "2023-12-05T06:30:00Z",
      "duration_minutes": 495,
      "created_at": "2023-12-04T22:15:00Z"
    }
  ],
  "pagination": {
    "current_page": 1,
    "total_pages": 2,
    "total_count": 25,
    "per_page": 20
  },
  "meta": {
    "date_range": {
      "from": "2023-12-01T00:00:00Z",
      "to": "2023-12-07T23:59:59Z"
    },
    "total_following": 3,
    "following_with_records": 2
  }
}
```

---

## 4. Error Responses

### Standard Error Format
All error responses follow this structure:

```json
{
  "error": "Human readable error message",
  "error_code": "MACHINE_READABLE_CODE",
  "details": {
    "field": "specific error details"
  }
}
```

### Common HTTP Status Codes

- **200 OK**: Successful GET/PUT/PATCH requests
- **201 Created**: Successful POST requests
- **204 No Content**: Successful DELETE requests
- **400 Bad Request**: Missing X-USER-ID header or invalid request format
- **401 Unauthorized**: Invalid user ID in X-USER-ID header
- **403 Forbidden**: User lacks permission for resource
- **404 Not Found**: Resource doesn't exist
- **409 Conflict**: Resource conflict (e.g., already following)
- **422 Unprocessable Entity**: Validation errors
- **429 Too Many Requests**: Rate limiting exceeded
- **500 Internal Server Error**: Unexpected server error

### Validation Error Example
```json
{
  "error": "Validation failed",
  "error_code": "VALIDATION_ERROR",
  "details": {
    "following_id": ["can't be blank", "must be a valid user ID"],
    "bedtime": ["can't be in the future"]
  }
}
```

---

## 5. Rate Limiting

- **General endpoints**: 100 requests per minute per user
- **Sleep record creation**: 10 requests per minute per user
- **Follow/Unfollow**: 20 requests per minute per user

Rate limit headers included in responses:
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1623456789
```

---

## 6. Data Models

### User
```ruby
# Users table (pre-existing)
- id: integer (primary key)
- name: string
```

### SleepRecord
```ruby
# Sleep records table
- id: integer (primary key)
- user_id: integer (foreign key)
- bedtime: datetime
- wake_time: datetime (nullable)
- duration_minutes: integer (calculated, nullable)
- created_at: datetime
- updated_at: datetime

# Indexes
- user_id
- bedtime
- created_at
- duration_minutes (for sorting)
```

### Follow
```ruby
# Follows table (join table)
- id: integer (primary key)
- follower_id: integer (foreign key to users)
- following_id: integer (foreign key to users)
- created_at: datetime

# Indexes
- [follower_id, following_id] (unique)
- follower_id
- following_id
```

---

## 7. Performance Considerations

### Database Optimization
- Composite indexes on frequently queried combinations
- Pagination for all list endpoints
- Database connection pooling
- Query optimization with includes/joins for N+1 prevention

### Caching Strategy
- Redis for frequently accessed following relationships
- Cache following users' sleep records for short periods
- Cache user basic info (id, name)

### API Performance
- JSON response compression
- Efficient SQL queries with proper JOINs
- Background job processing for heavy computations
- API response time monitoring

### Scalability Features
- Pagination on all list endpoints
- Configurable page sizes with reasonable limits
- Database query optimization
- Efficient sorting algorithms for large datasets

---

## 8. Security Considerations

- Input validation on all parameters
- SQL injection prevention through parameterized queries
- Rate limiting to prevent abuse
- X-USER-ID header validation on all requests
- User existence verification for provided user IDs
- User authorization checks for all operations (users can only access their own data)
- Data privacy (users can only see followed users' data)
- Input validation and sanitization for all request parameters
- Environment-specific endpoint restrictions (testing APIs disabled in production)

---

## 9. Future Enhancements

Potential API extensions (not in current scope):
- Sleep quality ratings
- Sleep goals and tracking
- Notification settings for following users' activities  
- Sleep analytics and insights
- Export functionality for personal data
- Timezone-aware operations
- Mobile push notifications webhooks