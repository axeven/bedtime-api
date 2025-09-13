# CLAUDE.md - Development Context & Guidelines

## Project Overview
**Bedtime API** - Rails-based RESTful API for sleep tracking with social features
- **Tech Stack**: Rails 8.0.2, PostgreSQL, Redis, Docker
- **Development Approach**: Test-Driven Development (TDD)
- **Architecture**: API-only, microservices-ready with Docker

## Important Project Decisions Made

### Authentication Strategy
- **X-USER-ID Header**: Simple header-based user identification
- **No complex auth**: Avoid JWT/session complexity for this implementation
- **Testing endpoint**: POST `/api/v1/users` for development only

### Database Configuration
- **PostgreSQL**: Switched from SQLite3 to PostgreSQL for production readiness
- **Environment Variables**: Database connection uses env vars for flexibility
- **Docker-based**: All database operations through Docker containers

### API Design Principles
- **Consistent terminology**: Use "following/follower" NOT "friends"
- **RESTful conventions**: Proper HTTP methods and status codes
- **Versioned API**: All endpoints under `/api/v1/`
- **JSON-only responses**: Standardized error/success formats

### Development Environment
- **Docker-first**: Primary development through docker-compose
- **Live reloading**: Volume mounting for code changes
- **Bundle exec**: Always use `bundle exec rails` in Docker commands

## Implementation Planning Patterns

### High-Level Plan Structure
- **6 Phases**: Foundation → Core Features → Social → Performance → Production
- **Checklist Format**: Use ✅ ⬜ 🟡 for progress tracking
- **Progressive Phases**: Each phase builds on previous, complete end-to-end

### Detailed Plan Structure
- **Step-by-Step Breakdown**: Each phase divided into 7 concrete steps
- **TDD Focus**: "Tests to Write First" section in every step
- **Implementation Details**: Code examples and bash commands
- **Acceptance Criteria**: Specific, measurable success conditions
- **Progress Tracking**: Mark completed items with [x]

## Key Commands & Workflows

### Docker Development Workflow
```bash
# Start all services
docker-compose up -d

# Database operations
docker-compose exec web bundle exec rails db:create
docker-compose exec web bundle exec rails db:migrate
docker-compose exec web bundle exec rails console

# Testing
docker-compose --profile test run --rm test

# Check logs
docker-compose logs web -f
```

### Testing Strategy
- **Write tests first**: Before any implementation
- **Three types**: Unit tests, Integration tests, Performance tests
- **Coverage requirement**: >90% code coverage
- **Quality gates**: All tests must pass before next phase

## Important Implementation Guidelines

### When Working on Features
1. **Update TodoWrite**: Track progress with specific, actionable items
2. **Follow TDD**: Write failing test → implement → refactor
3. **Update docs**: Keep phase_1_plan.md and high_level_plan.md current
4. **Test end-to-end**: Manual testing with curl commands
5. **Docker-only**: Use Docker for all Rails commands

### API Endpoint Development
- **Header validation**: Always check X-USER-ID header
- **Error handling**: Consistent JSON error responses with error_codes
- **Authorization**: Users can only access their own data + followed users
- **Pagination**: Implement on all list endpoints
- **Performance**: Optimize queries, prevent N+1 problems

### Database Operations
- **Docker-based**: Use `docker-compose exec web bundle exec rails`
- **Environment variables**: Use DATABASE_HOST, DATABASE_USER, etc.
- **Migrations**: Always run through Docker container
- **Testing**: Separate test database configuration

## Code Quality Standards

### Required Before Moving to Next Phase
- [ ] All tests pass (unit + integration)
- [ ] Code coverage > 90%
- [ ] Manual testing scenarios validated
- [ ] Documentation updated (API docs, implementation plans)
- [ ] Code review completed
- [ ] No linting violations

### Testing Requirements
- **Unit Tests**: All model validations, associations, business logic
- **Integration Tests**: Full API request/response cycles
- **Error Scenarios**: Test all failure modes and edge cases
- **Performance Tests**: Database query optimization (Phase 5+)

## Phase-Specific Reminders

### Phase 1 (Foundation) - Current
- ✅ Step 1: Rails setup completed
- 🎯 Next: User model with validations
- **Focus**: Solid foundation, proper error handling
- **Key deliverable**: Working user creation endpoint

### Future Phases
- **Phase 2**: Sleep records (clock in/out, duration calculation)
- **Phase 3**: Social following (follow/unfollow, lists)
- **Phase 4**: Social sleep data (viewing followed users' records)
- **Phase 5**: Performance (indexing, caching, optimization)
- **Phase 6**: Production readiness (security, logging, deployment)

## Common Pitfalls to Avoid

### Technical Issues
- **Rails commands**: Always use `bundle exec` in Docker
- **Database connections**: Ensure containers are healthy before operations
- **Authentication**: Don't overcomplicate - X-USER-ID header is sufficient
- **Terminology**: Stick to "following/follower" not "friends"

### Process Issues
- **Scope creep**: Stick to defined acceptance criteria per phase
- **Testing gaps**: Write tests FIRST, not after implementation
- **Documentation lag**: Update plans immediately after completing steps
- **Docker issues**: Use docker-compose for consistency

## Useful Development Commands

### Quick Health Checks
```bash
# Test database connection
docker-compose exec web bundle exec rails runner "puts ActiveRecord::Base.connection.execute('SELECT version()').first"

# Test Rails server
curl http://localhost:3000/up

# Check container status
docker-compose ps

# View recent logs
docker-compose logs web --tail=20
```

### API Testing
```bash
# Create test user
curl -X POST http://localhost:3000/api/v1/users \
  -H "Content-Type: application/json" \
  -d '{"name": "Test User"}'

# Test with user header
curl -H "X-USER-ID: 1" http://localhost:3000/api/v1/endpoint
```

## Success Metrics & Goals

### Phase Completion Criteria
- All acceptance criteria met ✅
- Comprehensive test coverage ✅  
- Manual validation successful ✅
- Documentation updated ✅
- Code review approved ✅

### Overall Project Success
- API fully functional per requirements
- Performance targets met under load
- Security best practices implemented
- Scalable architecture established
- Comprehensive test coverage achieved

---

## Notes for Future Claude Sessions

### Always Remember To:
1. Check current phase status in implementation plans
2. Use TodoWrite tool to track granular progress
3. Follow TDD approach religiously
4. Use Docker commands for all Rails operations
5. Update documentation as you progress
6. Test both success and error scenarios
7. Maintain consistent API terminology (following/follower)
8. Verify X-USER-ID authentication on protected endpoints

### Quick Project Status Check:
- **Current Phase**: Phase 1 (Foundation & Basic User Management)
- **Completed**: Step 1 - Rails Application Setup ✅
- **Next**: Step 2 - User Model & Database Schema
- **Environment**: Rails 8.0.2, PostgreSQL, Docker, API-only
- **Authentication**: X-USER-ID header-based