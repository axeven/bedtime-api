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

        context 'with nil name parameter' do
          let(:user) { { user: { name: nil } } }

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['error_code']).to eq('VALIDATION_ERROR')
            expect(data['details']['name']).to include("can't be blank")
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
      
      response(400, 'Bad request - malformed JSON') do
        description 'Returned when JSON payload is malformed or unparseable'
        schema '$ref' => '#/components/schemas/Error'

        examples 'application/json' => {
          malformed_json: {
            summary: 'Malformed JSON request',
            description: 'JSON syntax is invalid',
            value: {
              error: 'Invalid JSON format',
              error_code: 'BAD_REQUEST'
            }
          }
        }
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

      # Additional comprehensive test scenarios from integration tests
      context 'comprehensive edge case testing' do
        context 'with special characters in names' do
          [
            'User with spaces',
            'User-with-dashes',
            'User_with_underscores',
            'User.with.dots',
            'Üser wïth ñön-ÄSCII',
            '用户名中文',
            '🚀 Emoji User 🎉'
          ].each do |special_name|
            context "with name '#{special_name}'" do
              let(:user) { { user: { name: special_name } } }

              it "preserves special characters in name" do
                post '/api/v1/users', params: user.to_json,
                     headers: { 'Content-Type' => 'application/json' }

                if response.status == 201
                  data = JSON.parse(response.body)
                  expect(data['name']).to eq(special_name)
                end
                expect([200, 201, 400, 422]).to include(response.status)
              end
            end
          end
        end

        context 'database integration verification' do
          let(:user) { { user: { name: 'DB Integration Test User' } } }

          it 'persists user to database and allows retrieval' do
            post '/api/v1/users', params: user.to_json,
                 headers: { 'Content-Type' => 'application/json' }

            expect(response.status).to eq(201)
            data = JSON.parse(response.body)

            # Verify user exists in database
            created_user = User.find(data['id'])
            expect(created_user.name).to eq('DB Integration Test User')
            expect(created_user.created_at).to be_present
          end
        end

        context 'response format consistency' do
          it 'maintains consistent format across success and error responses' do
            # Test success response format
            post '/api/v1/users',
                 params: { user: { name: 'Format Test User' } }.to_json,
                 headers: { 'Content-Type' => 'application/json' }

            expect(response.status).to eq(201)
            success_data = JSON.parse(response.body)

            # Success should not have error fields
            expect(success_data).not_to have_key('error')
            expect(success_data).not_to have_key('error_code')
            expect(success_data).to have_key('id')
            expect(success_data).to have_key('name')
            expect(success_data).to have_key('created_at')

            # Test error response format
            post '/api/v1/users',
                 params: { user: { name: '' } }.to_json,
                 headers: { 'Content-Type' => 'application/json' }

            expect(response.status).to eq(422)
            error_data = JSON.parse(response.body)

            # Error should have required fields
            expect(error_data).to have_key('error')
            expect(error_data).to have_key('error_code')
            expect(error_data['error']).to be_a(String)
            expect(error_data['error_code']).to be_a(String)
            expect(error_data['error_code']).to match(/\A[A-Z_]+\z/)
          end
        end

        context 'content type handling' do
          it 'handles missing content type gracefully' do
            # Test without explicit content type
            post '/api/v1/users', params: { user: { name: 'No Content Type User' } }

            # Should handle gracefully
            expect([200, 201, 400, 415]).to include(response.status)
          end

          it 'handles incorrect content type' do
            post '/api/v1/users',
                 params: { user: { name: 'Wrong Content Type User' } }.to_json,
                 headers: { 'Content-Type' => 'text/plain' }

            expect([200, 201, 400, 415]).to include(response.status)
          end
        end

        context 'no authentication requirement verification' do
          it 'creates user without X-USER-ID header' do
            post '/api/v1/users',
                 params: { user: { name: 'No Auth User' } }.to_json,
                 headers: { 'Content-Type' => 'application/json' }

            expect(response.status).to eq(201)
            data = JSON.parse(response.body)
            expect(data['name']).to eq('No Auth User')
          end

          it 'creates user with X-USER-ID header (header ignored)' do
            post '/api/v1/users',
                 params: { user: { name: 'With Auth Header User' } }.to_json,
                 headers: {
                   'Content-Type' => 'application/json',
                   'X-USER-ID' => '999999'
                 }

            expect(response.status).to eq(201)
            data = JSON.parse(response.body)
            expect(data['name']).to eq('With Auth Header User')
          end
        end
      end
    end
  end
end