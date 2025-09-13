# frozen_string_literal: true

require 'rails_helper'
require_relative 'support/documentation_helper'
require_relative 'support/authentication_helpers'
require_relative 'support/sleep_record_schemas'

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  # NOTE: If you're using the rswag-api to serve API descriptions, you'll need
  # to ensure that it's configured to serve Swagger from the same folder
  config.openapi_root = Rails.root.join('swagger').to_s

  # Define one or more Swagger documents and provide global metadata for each one
  # When you run the 'rswag:specs:swaggerize' rake task, the complete Swagger will
  # be generated at the provided relative path under openapi_root
  # By default, the operations defined in spec files are added to the first
  # document below. You can override this behavior by adding a openapi_spec tag to the
  # the root example_group in your specs, e.g. describe '...', openapi_spec: 'v2/swagger.json'
  config.openapi_specs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'Bedtime API V1',
        version: 'v1',
        description: 'API for sleep tracking with social features',
        contact: {
          name: 'API Support',
          url: 'https://github.com/axeven/bedtime-api'
        }
      },
      paths: {},
      servers: [
        {
          url: 'http://localhost:3000',
          description: 'Development server'
        }
      ],
      components: {
        securitySchemes: {
          user_id_header: {
            type: 'apiKey',
            name: 'X-USER-ID',
            in: 'header',
            description: 'User identification header'
          }
        },
        schemas: {
          Error: {
            type: :object,
            properties: {
              error: { type: :string, description: 'Error message' },
              error_code: { type: :string, description: 'Error code for programmatic handling' }
            },
            required: ['error', 'error_code'],
            example: {
              error: 'Resource not found',
              error_code: 'NOT_FOUND'
            }
          },
          ValidationError: {
            allOf: [
              { '$ref' => '#/components/schemas/Error' },
              {
                type: :object,
                properties: {
                  details: {
                    type: :object,
                    additionalProperties: {
                      type: :array,
                      items: { type: :string }
                    },
                    description: 'Detailed validation errors by field'
                  }
                },
                example: {
                  error: 'Validation failed',
                  error_code: 'VALIDATION_ERROR',
                  details: {
                    name: ["can't be blank"]
                  }
                }
              }
            ]
          },
          User: {
            type: :object,
            properties: {
              id: { type: :integer, description: 'User ID', example: 1 },
              name: { type: :string, description: 'User name', example: 'John Doe' },
              created_at: {
                type: :string,
                format: :datetime,
                description: 'User creation timestamp',
                example: '2024-01-15T10:30:00Z'
              }
            },
            required: ['id', 'name', 'created_at']
          },
          SleepRecord: SleepRecordSchemas.sleep_record_schema,
          SleepRecordsCollection: SleepRecordSchemas.sleep_records_collection_schema,
          ClockInRequest: SleepRecordSchemas.clock_in_request_schema,
          ClockOutRequest: SleepRecordSchemas.clock_out_request_schema,
          ActiveSessionError: SleepRecordSchemas.active_session_error_schema,
          NoActiveSessionError: SleepRecordSchemas.no_active_session_error_schema
        }
      }
    }
  }

  # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'.
  # The openapi_specs configuration option has the filename including format in
  # the key, this may want to be changed to avoid putting yaml in json files.
  # Defaults to json. Accepts ':json' and ':yaml'.
  config.openapi_format = :yaml
end
