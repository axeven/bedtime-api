# Bedtime API

A high-performance Rails 8 RESTful API for tracking sleep patterns and social sleep sharing. Features comprehensive caching, performance optimizations, and robust CI/CD pipeline. Users can track sleep, follow others, and analyze social sleep patterns with enterprise-grade performance and security.

## Overview

The Bedtime API allows users to:
- Track their sleep by clocking in when going to bed and clocking out when waking up
- Follow and unfollow other users
- View sleep records from followed users, sorted by sleep duration

## Features

### 🛌 Sleep Tracking
- **Clock In/Out**: Record bedtime and wake-up times
- **Sleep Duration**: Automatic calculation of sleep duration
- **Sleep History**: View personal sleep records ordered by date
- **Active Session**: Track current incomplete sleep sessions

### 👥 Social Following
- **Follow Users**: Follow other users to see their sleep patterns
- **Unfollow Users**: Manage your following list
- **Following List**: View users you're currently following
- **Followers List**: See who's following you

### 📊 Social Sleep Insights
- **Following Users' Sleep Records**: View sleep data from users you follow
- **Duration-Based Sorting**: Records sorted by sleep duration (longest first)
- **Weekly View**: Sleep records from the previous 7 days
- **Mixed Leaderboard**: Aggregated view of all followed users' sleep performance
- **Performance Analytics**: Comprehensive sleep statistics and aggregations

### ⚡ Performance & Caching
- **Redis Caching**: Intelligent caching for frequently accessed data
- **Database Optimization**: Strategic indexing and query optimization
- **N+1 Prevention**: Optimized database queries with proper includes
- **Pagination**: Efficient pagination for all list endpoints
- **Cache Warming**: Proactive cache warming for critical user data

### 🔒 Security & Quality
- **Security Scanning**: Automated Brakeman security analysis (zero vulnerabilities)
- **Code Quality**: RuboCop linting with zero style violations
- **Test Coverage**: Comprehensive RSpec test suite (326+ tests)
- **CI/CD Pipeline**: GitHub Actions with PostgreSQL and Redis services

## API Documentation

### Base URL
```
/api/v1
```

### Authentication
All API requests require the `X-USER-ID` header to identify the user:

```bash
curl -H "X-USER-ID: 1" http://localhost:3000/api/v1/sleep_records
```

### Core Endpoints

#### Sleep Records
- `POST /api/v1/sleep_records` - Clock in (start sleep)
- `PATCH /api/v1/sleep_records/:id` - Clock out (end sleep)
- `GET /api/v1/sleep_records` - Get user's sleep history
- `GET /api/v1/sleep_records/current` - Get active sleep session

#### Following System
- `POST /api/v1/follows` - Follow a user
- `DELETE /api/v1/follows/:following_id` - Unfollow a user
- `GET /api/v1/follows` - Get following list
- `GET /api/v1/followers` - Get followers list

#### Social Sleep Data
- `GET /api/v1/following/sleep_records` - Get sleep records from followed users

#### Admin & Monitoring
- `GET /api/v1/admin/cache/stats` - Cache performance statistics
- `GET /api/v1/admin/cache/debug?user_id=X` - User-specific cache inspection
- `POST /api/v1/admin/cache/clear?user_id=X` - Clear user caches
- `POST /api/v1/admin/cache/warm?user_id=X` - Warm user caches

#### Testing (Development Only)
- `POST /api/v1/users` - Create a test user

## Quick Start

### Option 1: Docker Development (Recommended)

The easiest way to get started is using Docker Compose, which provides all dependencies out of the box.

#### Prerequisites
- Docker Engine 20.10+
- Docker Compose 2.0+

#### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd bedtime-api
   ```

2. **Start all services**
   ```bash
   docker-compose up --build
   ```

The API will be available at `http://localhost:3000`

That's it! The database, Redis, and Rails application will all start automatically.

### Option 2: Local Development

#### Prerequisites
- Ruby 3.4.5
- Rails 8.0.2+
- PostgreSQL 15+
- Redis 7+ (required for caching)

#### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd bedtime-api
   ```

2. **Install dependencies**
   ```bash
   bundle install
   ```

3. **Setup database**
   ```bash
   rails db:create
   rails db:migrate
   rails db:seed  # Optional: creates sample data
   ```

4. **Start the server**
   ```bash
   rails server
   ```

The API will be available at `http://localhost:3000`

## Example Usage

### API Testing Examples

Once your development environment is running (either Docker or local), you can test the API:

1. **Create test users** (development only)
   ```bash
   # Create first user
   curl -X POST http://localhost:3000/api/v1/users \
     -H "Content-Type: application/json" \
     -d '{"name": "Alice"}'

   # Create second user  
   curl -X POST http://localhost:3000/api/v1/users \
     -H "Content-Type: application/json" \
     -d '{"name": "Bob"}'
   ```

2. **Clock in for sleep** (User 1)
   ```bash
   curl -X POST http://localhost:3000/api/v1/sleep_records \
     -H "X-USER-ID: 1" \
     -H "Content-Type: application/json" \
     -d '{"action": "clock_in"}'
   ```

3. **Clock out from sleep** (User 1)
   ```bash
   curl -X PATCH http://localhost:3000/api/v1/sleep_records/1 \
     -H "X-USER-ID: 1" \
     -H "Content-Type: application/json" \
     -d '{"action": "clock_out"}'
   ```

4. **Follow another user** (User 1 follows User 2)
   ```bash
   curl -X POST http://localhost:3000/api/v1/follows \
     -H "X-USER-ID: 1" \
     -H "Content-Type: application/json" \
     -d '{"following_id": 2}'
   ```

5. **View personal sleep records**
   ```bash
   curl -H "X-USER-ID: 1" \
     http://localhost:3000/api/v1/sleep_records
   ```

6. **View following users' sleep records**
   ```bash
   curl -H "X-USER-ID: 1" \
     http://localhost:3000/api/v1/following/sleep_records
   ```

### Development Workflow Tips

#### Docker Development
- **Live Reloading**: Code changes are automatically reflected (no container restart needed)
- **Database Persistence**: Data persists between `docker-compose down/up`
- **Clean Slate**: Use `docker-compose down -v` to reset everything including data

#### Adding New Features
1. Make code changes in your editor
2. Changes are immediately available (Docker volume mounting)
3. Run migrations if needed: `docker-compose exec web rails db:migrate`
4. Test your changes with curl or your preferred API client
5. Run tests: `docker-compose --profile test run --rm test`

#### Debugging
- **Interactive Debugging**: Add `binding.pry` to your code
- **Container Shell**: `docker-compose exec web bash`
- **View Logs**: `docker-compose logs -f web`
- **Database Inspection**: `docker-compose exec postgres psql -U bedtime_user -d bedtime_development`

## Database Schema

### Core Models

**User**
- `id` (integer, primary key)
- `name` (string)

**SleepRecord**
- `id` (integer, primary key)
- `user_id` (integer, foreign key)
- `bedtime` (datetime)
- `wake_time` (datetime, nullable)
- `duration_minutes` (integer, calculated)
- `created_at`, `updated_at` (datetime)

**Follow**
- `id` (integer, primary key)
- `user_id` (integer, foreign key to users)
- `following_user_id` (integer, foreign key to users)
- `created_at` (datetime)

## Development Guide

### Docker Development Commands

#### Daily Development Workflow

```bash
# Start all services (first time or after changes to docker files)
docker-compose up --build

# Start services in background
docker-compose up -d

# View application logs
docker-compose logs -f web

# Stop all services
docker-compose down
```

#### Database Operations

```bash
# Run database migrations
docker-compose exec web rails db:migrate

# Seed the database with sample data
docker-compose exec web rails db:seed

# Reset database (drop, create, migrate, seed)
docker-compose exec web rails db:reset

# Open Rails console
docker-compose exec web rails console

# Open database console
docker-compose exec postgres psql -U bedtime_user -d bedtime_development
```

#### Code Changes and Debugging

```bash
# Access Rails container shell
docker-compose exec web bash

# View all service logs
docker-compose logs -f

# Restart just the web service (after Gemfile changes)
docker-compose restart web

# Rebuild containers (after major changes)
docker-compose build --no-cache
docker-compose up -d
```

#### Container Management

```bash
# View running containers
docker-compose ps

# Stop and remove all containers and volumes
docker-compose down -v

# Remove unused Docker resources
docker system prune -a
```

### Testing

#### With Docker (RSpec)

```bash
# Run all tests
docker-compose --profile test run --rm test

# Run specific test file
docker-compose exec web bundle exec rspec spec/models/user_spec.rb

# Run specific test category
docker-compose exec web bundle exec rspec spec/integration/
docker-compose exec web bundle exec rspec spec/performance/

# Run tests interactively
docker-compose exec web bash
bundle exec rspec

# Run tests with progress format
docker-compose exec web bundle exec rspec --format progress
```

#### Local Development (RSpec)

```bash
# Run all tests
bundle exec rspec

# Run specific test files
bundle exec rspec spec/models/user_spec.rb
bundle exec rspec spec/controllers/api/v1/sleep_records_controller_spec.rb

# Run tests with different formats
bundle exec rspec --format documentation
bundle exec rspec --format progress

# Run performance tests
bundle exec rspec spec/performance/
```

#### CI/CD Pipeline

The project includes a comprehensive GitHub Actions CI pipeline:

```bash
# Security scanning (Brakeman)
bin/brakeman --no-pager

# Code linting (RuboCop)
bin/rubocop -f github

# Full test suite with services
bin/rspec --format progress
```

**Services in CI:**
- PostgreSQL 15 with health checks
- Redis 7 with health checks
- Automated database setup and migrations

## Performance & Scalability

### Database Optimization
- **Strategic Indexing**: 8 optimized indexes for common query patterns
- **Composite Indexes**: Multi-column indexes for complex queries
- **Partial Indexes**: Conditional indexes for completed sleep records
- **Query Optimization**: Efficient JOINs and includes to prevent N+1 queries
- **Index Effectiveness Testing**: Automated EXPLAIN ANALYZE validation

### Redis Caching Strategy
- **Intelligent Caching**: Only caches frequently accessed small datasets (≤20 items)
- **Pattern-Based Keys**: Centralized cache key management with constants
- **Expiration Management**: Tailored expiration times per data type
  - Following/Followers Lists: 1 hour
  - Count Caches: 1 hour
  - Sleep Statistics: 30 minutes
  - Social Sleep Records: 5 minutes
- **Cache Warming**: Proactive cache warming for critical user data
- **Pattern Deletion**: Bulk cache invalidation using wildcard patterns
- **Cache Monitoring**: Real-time cache statistics and debugging tools

### Performance Features
- **Pagination**: Efficient offset/limit pagination for all list endpoints
- **Batch Loading**: ActiveRecord preloading to prevent N+1 queries
- **Query Counting**: Development query monitoring and N+1 detection
- **Performance Benchmarking**: Built-in performance testing utilities
- **Memory Tracking**: Memory usage monitoring for expensive operations

### Monitoring & Debugging
- **Cache Statistics**: Hit rates, memory usage, key counts
- **Performance Helpers**: Query analysis and benchmarking tools
- **Admin Endpoints**: Cache inspection and management tools
- **Rake Tasks**: Command-line cache management utilities

## API Response Format

All API responses follow a consistent JSON format:

**Success Response:**
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

**Error Response:**
```json
{
  "error": "Human readable error message",
  "error_code": "MACHINE_READABLE_CODE",
  "details": {
    "field": ["specific validation errors"]
  }
}
```

**Paginated Response:**
```json
{
  "sleep_records": [...],
  "pagination": {
    "current_page": 1,
    "total_pages": 5,
    "total_count": 100,
    "per_page": 20
  }
}
```

## Security

### Security Features
- **Input Validation**: All parameters are validated and sanitized
- **User Authorization**: Users can only access their own data and data from users they follow
- **Header Validation**: X-USER-ID header validation on all requests
- **SQL Injection Prevention**: Parameterized queries throughout with ActiveRecord::Relation validation
- **Environment Restrictions**: Testing endpoints disabled in production

### Security Scanning & Quality Assurance
- **Brakeman Analysis**: Automated security vulnerability scanning (zero vulnerabilities)
- **Code Quality**: RuboCop linting with comprehensive style enforcement (zero violations)
- **Test Coverage**: Extensive RSpec test suite with 326+ tests covering:
  - Unit tests for models and services
  - Integration tests for complete workflows
  - Performance tests for optimization validation
  - Security tests for vulnerability prevention

### CI/CD Security Pipeline
- **Automated Security Scanning**: Every commit scanned for vulnerabilities
- **Code Quality Gates**: All pull requests must pass linting and security checks
- **Test Requirements**: Full test suite must pass before deployment
- **GitHub Actions**: Secure CI pipeline with isolated test environments

## Development

### Code Structure
```
app/
├── controllers/
│   ├── api/v1/
│   │   ├── admin/
│   │   │   └── cache_controller.rb      # Cache management endpoints
│   │   ├── following/
│   │   │   └── sleep_records_controller.rb  # Social sleep data
│   │   ├── sleep_records_controller.rb
│   │   ├── follows_controller.rb
│   │   ├── followers_controller.rb
│   │   └── users_controller.rb
│   └── concerns/
│       ├── authenticatable.rb           # X-USER-ID authentication
│       └── query_countable.rb          # N+1 query prevention
├── models/
│   ├── user.rb                         # User model with cache warming
│   ├── sleep_record.rb                 # Sleep tracking with scopes
│   └── follow.rb                       # Follow relationships with cache invalidation
├── services/
│   └── cache_service.rb                # Centralized caching service
└── lib/
    ├── performance_helper.rb           # Performance testing utilities
    └── tasks/
        └── cache.rake                  # Cache management tasks
```

### Key Design Principles
- **RESTful Design**: Following REST conventions with consistent API patterns
- **Single Responsibility**: Each model and controller has clear responsibilities
- **Data Privacy**: Users only see data they're authorized to view
- **Performance First**: Optimized queries, intelligent caching, and strategic indexing
- **Scalability**: Built to handle growing user base and data volume
- **Cache-First Architecture**: Intelligent caching for frequently accessed data
- **Security by Design**: Comprehensive security scanning and validation
- **Test-Driven Development**: Extensive test coverage with performance validation
- **Observability**: Built-in monitoring and debugging capabilities

## Troubleshooting

### Docker Issues

**Port Already in Use:**
```bash
# Check what's using port 3000
sudo lsof -i :3000

# Kill the process or use different port in docker-compose.yml
ports:
  - "3001:3000"  # Maps container port 3000 to host port 3001
```

**Database Connection Issues:**
```bash
# Check if PostgreSQL container is running
docker-compose ps postgres

# Restart PostgreSQL
docker-compose restart postgres

# Reset database completely
docker-compose down -v
docker-compose up -d postgres
docker-compose exec web rails db:setup
```

**Container Build Issues:**
```bash
# Clean rebuild
docker-compose down
docker-compose build --no-cache
docker-compose up -d

# Clean up all Docker resources
docker system prune -a
```

**Permission Issues:**
```bash
# Fix file permissions (Linux/macOS)
sudo chown -R $USER:$USER .

# For Windows with WSL2, ensure code is in WSL filesystem
```

### Common Development Issues

**Gemfile Changes:**
```bash
# After adding/removing gems, rebuild the container
docker-compose build web
docker-compose up -d
```

**Migration Issues:**
```bash
# Check migration status
docker-compose exec web rails db:migrate:status

# Reset migrations (destructive!)
docker-compose exec web rails db:drop db:create db:migrate db:seed
```

**Test Database Issues:**
```bash
# Setup test database
docker-compose --profile test run --rm test bin/rails db:test:prepare

# Reset test database
docker-compose --profile test run --rm test bin/rails db:drop:test db:create:test db:migrate:test

# Run specific test categories
docker-compose exec web bundle exec rspec spec/performance/
docker-compose exec web bundle exec rspec spec/integration/
```

**Cache Issues:**
```bash
# Clear all caches
docker-compose exec web bundle exec rails runner "Rails.cache.clear"

# Check cache statistics
curl "http://localhost:3000/api/v1/admin/cache/stats"

# Warm user cache
curl -X POST "http://localhost:3000/api/v1/admin/cache/warm?user_id=1"

# Clear specific user cache
curl -X POST "http://localhost:3000/api/v1/admin/cache/clear?user_id=1"
```

**Performance Issues:**
```bash
# Run performance tests
docker-compose exec web bundle exec rspec spec/performance/

# Check database indexes
docker-compose exec web bundle exec rails runner "
  ActiveRecord::Base.connection.execute('SELECT * FROM pg_indexes WHERE tablename IN (\'users\', \'sleep_records\', \'follows\')').each { |r| puts r }
"

# Analyze query performance
docker-compose exec web bundle exec rails console
# > PerformanceHelper.test_index_effectiveness
```

## Documentation

- **User Stories**: [`docs/requirements/user_stories.md`](docs/requirements/user_stories.md)
- **API Design**: [`docs/requirements/initial_api_design.md`](docs/requirements/initial_api_design.md)
- **Cache Configuration**: [`docs/cache_configuration.md`](docs/cache_configuration.md)
- **Implementation Plans**: [`docs/implementation_plans/`](docs/implementation_plans/)
- **Docker Setup Guide**: [`docs/docker-setup.md`](docs/docker-setup.md)
- **Requirements**: [`docs/requirements/initial_requirement.pdf`](docs/requirements/initial_requirement.pdf)

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes with clear, descriptive commits
4. Write tests for your changes (RSpec)
5. Ensure all CI checks pass:
   - Security scan: `bin/brakeman --no-pager`
   - Code linting: `bin/rubocop -f github`
   - Full test suite: `bundle exec rspec`
6. Submit a pull request

### Commit Guidelines
- Use clear, descriptive commit messages
- Make separate commits for each logical change
- Follow the pattern: `type(scope): description`
  - `feat(cache): implement Redis caching layer`
  - `fix(performance): optimize N+1 queries in social feed`
  - `test(integration): add comprehensive workflow tests`
  - `perf(database): add strategic indexes for query optimization`

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For questions or issues:
1. Check the [API Documentation](docs/requirements/initial_api_design.md)
2. Review the [User Stories](docs/requirements/user_stories.md)
3. Open an issue in the repository

---

## Project Status

**Current Implementation Phase**: Phase 5 - Performance Optimization & Caching ✅

### ✅ Completed Features
- **Phase 1**: Foundation & Basic User Management
- **Phase 2**: Sleep Record Management (Clock In/Out)
- **Phase 3**: Social Following System
- **Phase 4**: Social Sleep Data Access
- **Phase 5**: Performance Optimization & Redis Caching

### 🔧 Technical Achievements
- **326+ RSpec Tests** with comprehensive coverage
- **Zero Security Vulnerabilities** (Brakeman verified)
- **Zero Code Style Violations** (RuboCop verified)
- **Strategic Database Indexing** with 8 optimized indexes
- **Redis Caching Layer** with intelligent cache management
- **CI/CD Pipeline** with PostgreSQL and Redis services
- **Performance Monitoring** with built-in benchmarking tools

### 📊 Performance Metrics
- **Database Queries**: Optimized with strategic indexing and N+1 prevention
- **Cache Hit Rates**: Monitored with real-time statistics
- **Response Times**: Benchmarked and optimized for sub-100ms queries
- **Memory Usage**: Tracked and optimized for efficient resource utilization

---

**Built with ❤️ using Ruby on Rails 8, PostgreSQL, Redis, and modern DevOps practices**