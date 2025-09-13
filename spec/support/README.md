# rswag Templates and Patterns for Phase 2

This directory contains reusable templates and patterns for documenting Phase 2 sleep tracking endpoints using rswag.

## Files Overview

### Core Helper Modules

- **`authentication_helpers.rb`** - Provides authentication patterns and test helpers
- **`documentation_helper.rb`** - General documentation patterns (from Phase 1.5 Step 3)
- **`sleep_record_schemas.rb`** - Schema definitions for sleep tracking entities

### Template Files

- **`sleep_records_spec.rb`** (in `spec/requests/api/v1/`) - Complete template for sleep record endpoints

## Usage Patterns for Phase 2

### 1. Authentication Requirements

For endpoints that require authentication, use the `AuthenticationHelpers` module:

```ruby
require 'swagger_helper'

RSpec.describe 'api/v1/your_endpoint', type: :request do
  include AuthenticationHelpers

  path '/api/v1/your_endpoint' do
    get('Your endpoint') do
      requires_authentication

      response(200, 'Success') do
        with_authenticated_user
        run_test!
      end

      document_authentication_errors
    end
  end
end
```

### 2. Schema References

Use the predefined schemas from `sleep_record_schemas.rb`:

```ruby
response(200, 'Sleep record retrieved') do
  schema '$ref' => '#/components/schemas/SleepRecord'
end

response(201, 'Sleep session started') do
  schema '$ref' => '#/components/schemas/SleepRecord'
end

response(422, 'Active session exists') do
  schema '$ref' => '#/components/schemas/ActiveSessionError'
end
```

### 3. Request Body Schemas

For endpoints that accept request bodies:

```ruby
parameter name: :sleep_record, in: :body, required: false,
  description: 'Sleep session data',
  schema: {
    type: :object,
    properties: {
      bedtime: {
        type: :string,
        format: :datetime,
        description: 'Custom bedtime',
        example: '2024-01-15T22:30:00Z'
      }
    }
  }
```

### 4. Comprehensive Examples

Always include realistic examples in responses:

```ruby
examples 'application/json' => {
  successful_clock_in: {
    summary: 'Successful sleep session start',
    description: 'User successfully clocked in for sleep',
    value: {
      id: 1,
      user_id: 1,
      bedtime: '2024-01-15T22:30:00Z',
      # ... other fields
    }
  }
}
```

## API Versioning Strategy

### Current Version: v1

All endpoints are currently under `/api/v1/` namespace:
- Users: `/api/v1/users`
- Sleep Records: `/api/v1/sleep_records`

### Version Headers

The API uses URL-based versioning rather than header-based versioning for simplicity and clarity.

### Future Versioning (v2+)

When breaking changes are needed:

1. **Create new namespace**: `/api/v2/`
2. **Update swagger_helper.rb**: Add new openapi_specs entry
3. **Maintain backward compatibility**: Keep v1 endpoints functional
4. **Update documentation**: Use separate swagger files per version

Example swagger_helper.rb for multiple versions:

```ruby
config.openapi_specs = {
  'v1/swagger.yaml' => {
    openapi: '3.0.1',
    info: { title: 'Bedtime API V1', version: 'v1' },
    # ... v1 config
  },
  'v2/swagger.yaml' => {
    openapi: '3.0.1',
    info: { title: 'Bedtime API V2', version: 'v2' },
    # ... v2 config with new schemas
  }
}
```

## Schema Evolution Guidelines

### Non-Breaking Changes (Same Version)
- Adding new optional fields
- Adding new optional query parameters
- Adding new response codes
- Adding new endpoints

### Breaking Changes (New Version Required)
- Removing fields from responses
- Changing field types
- Making optional fields required
- Changing URL structures
- Removing endpoints

## Testing Strategy for Phase 2

### 1. TDD with rswag

Write rswag specs BEFORE implementing endpoints:

```ruby
# 1. Write failing rswag spec
response(201, 'Sleep session started') do
  schema '$ref' => '#/components/schemas/SleepRecord'

  with_authenticated_user
  let(:sleep_record) { {} }

  run_test! do |response|
    # Test expectations here
  end
end

# 2. Implement endpoint to make spec pass
# 3. Refactor if needed
```

### 2. Documentation-Driven Development

Each endpoint should have:
- Clear description with workflow explanation
- Comprehensive parameter documentation
- Multiple response scenarios with examples
- Authentication requirements clearly documented
- Error scenarios with appropriate error codes

### 3. Consistent Error Handling

Use standard error response formats:

```ruby
{
  "error": "Human readable error message",
  "error_code": "MACHINE_READABLE_CODE",
  "details": {
    // Optional context-specific details
  }
}
```

Standard error codes for Phase 2:
- `MISSING_USER_ID` - X-USER-ID header missing
- `INVALID_USER_ID` - X-USER-ID header invalid format
- `USER_NOT_FOUND` - User doesn't exist
- `NOT_FOUND` - Resource not found
- `ACTIVE_SESSION_EXISTS` - User already has active sleep session
- `NO_ACTIVE_SESSION` - No active session to clock out from
- `VALIDATION_ERROR` - Request validation failed

## Integration with Existing Workflow

### 1. Documentation Generation

After implementing endpoints, always regenerate documentation:

```bash
docker-compose exec web bundle exec rake api_docs:update
```

### 2. Continuous Integration

Add to your CI/CD pipeline:
- Run rswag specs: `bundle exec rspec spec/requests/`
- Validate documentation: `bundle exec rake api_docs:validate`
- Generate fresh docs: `bundle exec rake api_docs:generate`

### 3. Manual Testing

Use the generated Swagger UI for manual testing:
- Development: `http://localhost:3000/api-docs`
- Interactive testing of all documented scenarios
- Validation of request/response formats

## Benefits of This Approach

1. **Documentation as Code** - Documentation stays in sync with implementation
2. **Interactive Testing** - Swagger UI enables easy manual testing
3. **Consistent Patterns** - Reusable helpers ensure consistency
4. **Comprehensive Coverage** - Tests serve as both validation and documentation
5. **Future-Proof** - Templates support easy expansion for new endpoints

## Next Steps for Phase 2 Implementation

1. Use `sleep_records_spec.rb` as template for actual implementation
2. Follow TDD: Write failing rswag specs first
3. Implement models, controllers, and business logic
4. Ensure all specs pass
5. Generate and validate documentation
6. Test manually using Swagger UI

This approach ensures that Phase 2 development maintains high documentation quality while following established patterns from Phase 1.5.