require 'swagger_helper'

RSpec.describe 'api/v1/users', type: :request do
  before do
    host! 'localhost:3000'
  end
  
  path '/api/v1/users' do
    post('Create a new user') do
      tags 'Users'
      description <<~DESC
        Creates a new user for development and testing purposes.
        
        **Note**: This endpoint is only available in development and test environments.
        
        **Validation Rules**:
        - Name is required and cannot be blank
        - Name must be between 1 and 100 characters
        - No authentication required for user creation
      DESC
      consumes 'application/json'
      produces 'application/json'
      
      parameter name: :user, in: :body, required: true,
        description: 'User creation payload',
        schema: {
          type: :object,
          properties: {
            user: {
              type: :object,
              description: 'User attributes',
              properties: {
                name: { 
                  type: :string,
                  description: 'Full name of the user',
                  example: 'John Doe',
                  minLength: 1,
                  maxLength: 100
                }
              },
              required: ['name'],
              additionalProperties: false
            }
          },
          required: ['user'],
          additionalProperties: false,
          example: {
            user: {
              name: 'Alice Johnson'
            }
          }
        }

      response(201, 'User created successfully') do
        description 'Returns the created user with generated ID and timestamp'
        schema '$ref' => '#/components/schemas/User'
        
        examples 'application/json' => {
          successful_creation: {
            summary: 'Successful user creation',
            description: 'User created with valid name',
            value: {
              id: 1,
              name: 'Alice Johnson',
              created_at: '2024-01-15T14:30:00Z'
            }
          }
        }

        let(:user) { { user: { name: 'Test User' } } }
        
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Test User')
          expect(data['id']).to be_present
          expect(data['created_at']).to be_present
          
          # Verify timestamp format
          expect { DateTime.iso8601(data['created_at']) }.not_to raise_error
        end
      end

      response(422, 'Validation failed') do
        description 'Returned when user data fails validation'
        schema '$ref' => '#/components/schemas/ValidationError'
        
        examples 'application/json' => {
          blank_name: {
            summary: 'Blank name validation error',
            description: 'Name cannot be empty',
            value: {
              error: 'Validation failed',
              error_code: 'VALIDATION_ERROR',
              details: {
                name: ["can't be blank"]
              }
            }
          },
          name_too_long: {
            summary: 'Name too long validation error',
            description: 'Name exceeds maximum length',
            value: {
              error: 'Validation failed',
              error_code: 'VALIDATION_ERROR',
              details: {
                name: ['is too long (maximum is 100 characters)']
              }
            }
          }
        }

        context 'with blank name' do
          let(:user) { { user: { name: '' } } }
          
          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['error_code']).to eq('VALIDATION_ERROR')
            expect(data['details']['name']).to include("can't be blank")
          end
        end
        
        context 'with name too long' do
          let(:user) { { user: { name: 'A' * 101 } } }
          
          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['error_code']).to eq('VALIDATION_ERROR')
            expect(data['details']['name']).to include('is too long (maximum is 100 characters)')
          end
        end
      end

      response(400, 'Bad request - missing parameters') do
        description 'Returned when required parameters are missing or invalid'
        schema '$ref' => '#/components/schemas/Error'
        
        examples 'application/json' => {
          missing_user_param: {
            summary: 'Missing user parameter',
            description: 'The user parameter is required',
            value: {
              error: 'param is missing or the value is empty or invalid: user',
              error_code: 'BAD_REQUEST'
            }
          },
          missing_name_param: {
            summary: 'Missing name parameter',
            description: 'The name parameter within user is required',
            value: {
              error: 'param is missing or the value is empty or invalid: name',
              error_code: 'BAD_REQUEST'
            }
          }
        }

        context 'with missing user parameter' do
          let(:user) { {} }
          
          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['error_code']).to eq('BAD_REQUEST')
            expect(data['error']).to include('param is missing')
          end
        end
        
        context 'with missing name parameter' do
          let(:user) { { user: {} } }
          
          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['error_code']).to eq('BAD_REQUEST')
            expect(data['error']).to include('param is missing')
          end
        end
      end
      
      response(500, 'Internal server error') do
        schema '$ref' => '#/components/schemas/Error'
        
        examples 'application/json' => {
          internal_error: {
            summary: 'Unexpected server error',
            description: 'An unexpected error occurred during user creation',
            value: {
              error: 'Internal server error',
              error_code: 'INTERNAL_ERROR'
            }
          }
        }
      end
    end
  end
end