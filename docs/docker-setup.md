# Docker Setup Guide

This guide explains how to run the Bedtime API using Docker and Docker Compose.

## Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+

## Quick Start

### 1. Clone and Start Services

```bash
# Clone the repository
git clone <repository-url>
cd bedtime-api

# Start all services
docker-compose up --build
```

The API will be available at `http://localhost:3000`

### 2. Initialize Database (First Time Only)

The database will be automatically initialized when the containers start. If you need to reset it:

```bash
# Reset database
docker-compose exec web rails db:drop db:create db:migrate db:seed
```

## Services Overview

### Core Services

| Service | Port | Description |
|---------|------|-------------|
| **web** | 3000 | Rails API application |
| **postgres** | 5432 | PostgreSQL database (development) |
| **redis** | 6379 | Redis cache server |

### Test Services (Optional)

| Service | Port | Description |
|---------|------|-------------|
| **postgres_test** | 5433 | PostgreSQL database (test) |
| **test** | - | Test runner container |

## Common Commands

### Development

```bash
# Start all services in development mode
docker-compose up

# Start in background
docker-compose up -d

# View logs
docker-compose logs -f web

# Stop all services
docker-compose down

# Rebuild and start
docker-compose up --build
```

### Database Operations

```bash
# Run migrations
docker-compose exec web rails db:migrate

# Seed database
docker-compose exec web rails db:seed

# Reset database
docker-compose exec web rails db:reset

# Open Rails console
docker-compose exec web rails console

# Open database console
docker-compose exec postgres psql -U bedtime_user -d bedtime_development
```

### Testing

```bash
# Run all tests
docker-compose --profile test run --rm test

# Run specific test file
docker-compose exec web rails test test/controllers/sleep_records_controller_test.rb

# Run tests with coverage
docker-compose exec web rails test:coverage
```

### Container Management

```bash
# Access Rails container shell
docker-compose exec web bash

# Access PostgreSQL container
docker-compose exec postgres bash

# View container status
docker-compose ps

# Remove all containers and volumes
docker-compose down -v --remove-orphans
```

## Configuration

### Environment Variables

The following environment variables are configured in `docker-compose.yml`:

**Rails Application (web service):**
```yaml
RAILS_ENV: development
DATABASE_HOST: postgres
DATABASE_NAME: bedtime_development
DATABASE_USER: bedtime_user
DATABASE_PASSWORD: bedtime_password
REDIS_URL: redis://redis:6379/0
```

**PostgreSQL (postgres service):**
```yaml
POSTGRES_DB: bedtime_development
POSTGRES_USER: bedtime_user
POSTGRES_PASSWORD: bedtime_password
```

### Custom Configuration

Create a `.env` file in the project root to override default settings:

```bash
# .env file
RAILS_MASTER_KEY=your_master_key_here
DATABASE_PASSWORD=your_custom_password
```

## Development Workflow

### 1. Daily Development

```bash
# Start services
docker-compose up -d

# Check logs if needed
docker-compose logs -f web

# Your Rails app runs on http://localhost:3000
# Make code changes - they'll be reflected immediately due to volume mounting
```

### 2. Adding New Gems

```bash
# After adding gems to Gemfile, rebuild the container
docker-compose build web
docker-compose up -d
```

### 3. Database Schema Changes

```bash
# After creating new migrations
docker-compose exec web rails db:migrate

# For test database
docker-compose --profile test exec postgres_test psql -U bedtime_user -c "DROP DATABASE IF EXISTS bedtime_test; CREATE DATABASE bedtime_test;"
docker-compose --profile test run --rm test rails db:migrate
```

## API Testing Examples

Once the services are running, you can test the API:

### 1. Create a Test User

```bash
curl -X POST http://localhost:3000/api/v1/users \
  -H "Content-Type: application/json" \
  -d '{"name": "Test User"}'
```

### 2. Clock In

```bash
curl -X POST http://localhost:3000/api/v1/sleep_records \
  -H "X-USER-ID: 1" \
  -H "Content-Type: application/json" \
  -d '{"action": "clock_in"}'
```

### 3. View Sleep Records

```bash
curl -H "X-USER-ID: 1" http://localhost:3000/api/v1/sleep_records
```

## Troubleshooting

### Common Issues

**Port Already in Use:**
```bash
# Find process using port 3000
sudo lsof -i :3000

# Or use different ports in docker-compose.yml
ports:
  - "3001:3000"  # Map to different host port
```

**Database Connection Issues:**
```bash
# Check if PostgreSQL is running
docker-compose ps postgres

# Check PostgreSQL logs
docker-compose logs postgres

# Reset PostgreSQL
docker-compose down
docker volume rm bedtime-api_postgres_data
docker-compose up -d postgres
```

**Redis Connection Issues:**
```bash
# Check Redis status
docker-compose exec redis redis-cli ping

# Should return "PONG"
```

**Container Build Issues:**
```bash
# Clean rebuild
docker-compose down
docker-compose build --no-cache
docker-compose up
```

### Debugging

**View All Logs:**
```bash
docker-compose logs -f
```

**Interactive Debugging:**
```bash
# Add binding.pry or byebug to your code, then:
docker-compose exec web bash
# Container will stop at breakpoint in interactive mode
```

**Database Debugging:**
```bash
# Connect to database directly
docker-compose exec postgres psql -U bedtime_user -d bedtime_development

# View tables
\dt

# View specific table
\d sleep_records
```

## Production Considerations

This Docker setup is optimized for development. For production:

1. Use the existing production `Dockerfile`
2. Set up proper secrets management
3. Use external PostgreSQL and Redis services
4. Configure proper logging and monitoring
5. Set up proper backup strategies

## File Structure

```
bedtime-api/
├── docker-compose.yml           # Main compose configuration
├── docker-compose.override.yml  # Development overrides
├── Dockerfile.dev              # Development Dockerfile
├── Dockerfile                  # Production Dockerfile (existing)
├── docker/
│   └── entrypoint.sh          # Container entrypoint script
└── docs/
    └── docker-setup.md        # This file
```

## Volumes and Data Persistence

- **postgres_data**: PostgreSQL development data
- **postgres_test_data**: PostgreSQL test data  
- **redis_data**: Redis cache data
- **bundle_cache**: Ruby gems cache for faster rebuilds
- **Application code**: Mounted as volume for live reloading

Data persists between container restarts but can be cleared with:
```bash
docker-compose down -v
```