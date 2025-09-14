module AuthenticationHelpers
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    # Add common authentication error responses
    def document_authentication_errors
      response(400, 'Missing authentication header') do
        description 'X-USER-ID header is required'
        schema '$ref' => '#/components/schemas/Error'

        examples 'application/json' => {
          missing_header: {
            summary: 'Missing X-USER-ID header',
            description: 'The X-USER-ID header is required for this endpoint',
            value: {
              error: 'X-USER-ID header is required',
              error_code: 'MISSING_USER_ID'
            }
          }
        }

        let(:'X-USER-ID') { nil }
        run_test!
      end

      response(404, 'User not found') do
        description 'The specified user ID does not exist'
        schema '$ref' => '#/components/schemas/Error'

        examples 'application/json' => {
          user_not_found: {
            summary: 'User not found',
            description: 'No user exists with the provided ID',
            value: {
              error: 'User not found',
              error_code: 'USER_NOT_FOUND'
            }
          }
        }

        let(:'X-USER-ID') { '999999' }
        run_test!
      end

      response(400, 'Invalid user ID format') do
        description 'X-USER-ID header must be a valid integer'
        schema '$ref' => '#/components/schemas/Error'

        examples 'application/json' => {
          invalid_format: {
            summary: 'Invalid user ID format',
            description: 'User ID must be a positive integer',
            value: {
              error: 'Invalid user ID format',
              error_code: 'INVALID_USER_ID'
            }
          }
        }

        let(:'X-USER-ID') { 'not-a-number' }
        run_test!
      end
    end

    # Helper to create a test user for authentication scenarios
    def with_authenticated_user
      let(:test_user) { User.create!(name: 'Test User') }
      let(:'X-USER-ID') { test_user.id.to_s }
    end

    # Helper to test different authentication scenarios
    def test_authentication_scenarios
      context 'authentication scenarios' do
        context 'with valid user ID' do
          with_authenticated_user
          run_test!
        end

        context 'with missing X-USER-ID header' do
          let(:'X-USER-ID') { nil }
          run_test! do |response|
            expect(response).to have_http_status(:bad_request)
            data = JSON.parse(response.body)
            expect(data['error_code']).to eq('MISSING_USER_ID')
          end
        end

        context 'with invalid user ID format' do
          let(:'X-USER-ID') { 'invalid' }
          run_test! do |response|
            expect(response).to have_http_status(:bad_request)
            data = JSON.parse(response.body)
            expect(data['error_code']).to eq('INVALID_USER_ID')
          end
        end

        context 'with non-existent user ID' do
          let(:'X-USER-ID') { '999999' }
          run_test! do |response|
            expect(response).to have_http_status(:not_found)
            data = JSON.parse(response.body)
            expect(data['error_code']).to eq('USER_NOT_FOUND')
          end
        end
      end
    end
  end
end