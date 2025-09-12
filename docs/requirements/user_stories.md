# User Stories - Bedtime Tracking API

## Epic: Sleep Tracking System
A Rails-based RESTful API system that allows users to track their sleep patterns and follow other users to view their sleep records.

---

## Feature 1: Sleep Clock In/Out Management

### Story 1.1: Record Sleep Time
**As a** user  
**I want to** clock in when I go to bed  
**So that** I can track when I start sleeping

**Acceptance Criteria:**
- API endpoint accepts clock-in requests for a user
- System records the timestamp when user goes to bed
- Each clock-in creates a new sleep record entry

### Story 1.2: Record Wake Up Time
**As a** user  
**I want to** clock out when I wake up  
**So that** I can complete my sleep tracking record

**Acceptance Criteria:**
- API endpoint accepts clock-out requests for a user
- System updates the existing sleep record with wake-up time
- System calculates and stores sleep duration automatically

### Story 1.3: View Personal Sleep History
**As a** user  
**I want to** see all my clocked-in times ordered by creation date  
**So that** I can review my sleep tracking history

**Acceptance Criteria:**
- API returns all sleep records for the authenticated user
- Records are ordered by created time (newest first)
- Response includes both bedtime and wake-up timestamps
- Response includes calculated sleep duration

---

## Feature 2: Social Following System

### Story 2.1: Follow Other Users
**As a** user  
**I want to** follow other users  
**So that** I can see their sleep patterns and compare with mine

**Acceptance Criteria:**
- API endpoint allows user to follow another user by user ID
- System creates a following relationship between users
- Prevents duplicate following relationships
- Returns confirmation of successful follow action

### Story 2.2: Unfollow Users
**As a** user  
**I want to** unfollow users I'm currently following  
**So that** I can manage my following list and stop seeing their sleep data

**Acceptance Criteria:**
- API endpoint allows user to unfollow another user by user ID
- System removes the following relationship
- Returns confirmation of successful unfollow action
- Handles cases where relationship doesn't exist gracefully

### Story 2.3: Manage Following List
**As a** user  
**I want to** view my list of followed users  
**So that** I can see who I'm currently following

**Acceptance Criteria:**
- API returns list of users that current user is following
- Response includes user ID and name for each followed user
- List is ordered consistently (e.g., by follow date or username)

---

## Feature 3: Social Sleep Records Viewing

### Story 3.1: View Following Users' Sleep Records
**As a** user  
**I want to** see sleep records from all users I follow from the previous week  
**So that** I can compare sleep patterns with users I follow and stay motivated

**Acceptance Criteria:**
- API returns sleep records from the past 7 days for all followed users
- Records are sorted by sleep duration (longest to shortest)
- Response includes user identification for each record
- Response includes bedtime, wake-up time, and duration
- Only includes complete sleep records (both clock-in and clock-out)

### Story 3.2: Mixed User Sleep Leaderboard
**As a** user  
**I want to** see an aggregated view of all followed users' sleep records mixed together  
**So that** I can see the overall sleep performance ranking among users I follow

**Acceptance Criteria:**
- API returns mixed list of sleep records from all followed users
- Multiple records from the same user can appear in the list
- Records are sorted by sleep duration (descending order)
- Each record clearly identifies which user it belongs to
- Limited to previous week's data only

---

## Feature 4: System Performance & Scalability

### Story 4.1: Handle High Concurrent Requests
**As a** system administrator  
**I want to** ensure the API can handle many simultaneous requests  
**So that** users experience consistent performance even during peak usage

**Acceptance Criteria:**
- API maintains response times under acceptable thresholds during concurrent access
- Database queries are optimized for performance
- Appropriate indexing is implemented on frequently queried fields
- Connection pooling is configured for database efficiency

### Story 4.2: Manage Growing User Base
**As a** system administrator  
**I want to** ensure the system scales efficiently with increasing users and data  
**So that** performance remains consistent as the platform grows

**Acceptance Criteria:**
- Database schema is designed for efficient querying at scale
- Pagination is implemented for large result sets
- Query optimization strategies are documented and implemented
- Caching strategies are implemented where appropriate

---

## Technical User Stories

### Story T1: RESTful API Structure
**As a** developer integrating with the system  
**I want to** use standardized RESTful endpoints  
**So that** the API is predictable and follows industry conventions

**Acceptance Criteria:**
- All endpoints follow REST naming conventions
- Appropriate HTTP methods are used (GET, POST, DELETE)
- Consistent JSON response format across all endpoints
- Proper HTTP status codes are returned

### Story T2: Comprehensive Test Coverage
**As a** developer maintaining the system  
**I want to** have comprehensive test coverage for all API endpoints  
**So that** I can confidently make changes without breaking functionality

**Acceptance Criteria:**
- Unit tests cover all model methods and validations
- Integration tests cover all API endpoints
- Tests cover both success and error scenarios
- Tests validate response formats and data accuracy

---

## Assumptions Made

1. **Sleep Cycle Model**: Each sleep record consists of a clock-in (bedtime) and clock-out (wake-up) pair
2. **User Authentication**: While not implemented, user identification is handled through some authentication mechanism
3. **Time Zone Handling**: All times are stored and returned in UTC, client handles timezone conversion
4. **Data Privacy**: Users can only see sleep records of users they actively follow
5. **Week Definition**: "Previous week" means the last 7 days from the current date
6. **Incomplete Records**: Only complete sleep cycles (with both clock-in and clock-out) are included in social views
7. **Follow Relationships**: Following is unidirectional (A can follow B without B following A)