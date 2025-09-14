# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'api/v1/sleep_records', type: :request do
  before do
    host! 'localhost:3000'
  end

  # Include authentication helpers
  include AuthenticationHelpers

  # Set up authenticated user for all tests
  with_authenticated_user

  path '/api/v1/sleep_records' do
    post('Clock in - Start sleep session') do
      tags 'Sleep Records'
      description <<~DESC
        Creates a new sleep session (clock-in) for the authenticated user.

        **Important Notes**:
        - Only one active sleep session is allowed per user
        - If bedtime is not provided, current timestamp is used
        - Returns 422 if user already has an active sleep session

        **Workflow**:
        1. User calls this endpoint to start tracking sleep
        2. System creates sleep record with bedtime and active=true
        3. User later calls PATCH /sleep_records/:id to clock out
      DESC
      consumes 'application/json'
      produces 'application/json'

      parameter name: 'X-USER-ID', in: :header, type: :string, required: true,
                description: 'User ID for authentication',
                example: '1'

      parameter name: :sleep_record, in: :body, required: false,
        description: 'Sleep session data (optional)',
        schema: {
          type: :object,
          properties: {
            bedtime: {
              type: :string,
              format: :datetime,
              description: 'Custom bedtime (defaults to current time)',
              example: '2024-01-15T22:30:00Z'
            }
          },
          additionalProperties: false
        }

      response(201, 'Sleep session started successfully') do
        description 'Returns the created sleep record with active=true'
        schema '$ref' => '#/components/schemas/SleepRecord'

        examples 'application/json' => {
          successful_clock_in: {
            summary: 'Successful sleep session start',
            description: 'User successfully clocked in for sleep',
            value: {
              id: 1,
              user_id: 1,
              bedtime: '2024-01-15T22:30:00Z',
              wake_time: nil,
              duration_minutes: nil,
              active: true,
              created_at: '2024-01-15T22:30:00Z',
              updated_at: '2024-01-15T22:30:00Z'
            }
          }
        }

        let(:sleep_record) { {} }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['user_id']).to eq(test_user.id)
          expect(data['active']).to be true
          expect(data['bedtime']).to be_present
          expect(data['wake_time']).to be_nil
          expect(data['duration_minutes']).to be_nil
        end
      end

      response(422, 'Active session already exists') do
        description 'User already has an active sleep session'
        schema '$ref' => '#/components/schemas/ActiveSessionError'

        examples 'application/json' => {
          active_session_exists: {
            summary: 'Active session conflict',
            description: 'User tried to clock in while already having an active session',
            value: {
              error: 'You already have an active sleep session',
              error_code: 'ACTIVE_SESSION_EXISTS',
              details: {
                active_session_id: 5,
                active_since: '2024-01-15T20:00:00Z'
              }
            }
          }
        }

        let(:sleep_record) { {} }

        before do
          # Create an active sleep session for the user
          test_user.sleep_records.create!(bedtime: 2.hours.ago)
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error_code']).to eq('ACTIVE_SESSION_EXISTS')
          expect(data['details']['active_session_id']).to be_present
        end
      end

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

        let(:sleep_record) { {} }
        let(:'X-USER-ID') { nil }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error_code']).to eq('MISSING_USER_ID')
        end
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

        let(:sleep_record) { {} }
        let(:'X-USER-ID') { '999999' }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error_code']).to eq('USER_NOT_FOUND')
        end
      end

      response(404, 'Invalid user ID format') do
        description 'X-USER-ID header with invalid format gets treated as user not found'
        schema '$ref' => '#/components/schemas/Error'

        examples 'application/json' => {
          invalid_format: {
            summary: 'Invalid user ID format',
            description: 'User ID with invalid format gets treated as non-existent user',
            value: {
              error: 'User not found',
              error_code: 'USER_NOT_FOUND'
            }
          }
        }

        let(:sleep_record) { {} }
        let(:'X-USER-ID') { 'not-a-number' }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error_code']).to eq('USER_NOT_FOUND')
        end
      end

      response(422, 'Future bedtime validation error') do
        description 'Bedtime cannot be in the future'
        schema '$ref' => '#/components/schemas/Error'

        examples 'application/json' => {
          future_bedtime: {
            summary: 'Future bedtime not allowed',
            description: 'User provided a bedtime in the future',
            value: {
              error: 'Validation failed: Bedtime cannot be in the future',
              error_code: 'VALIDATION_ERROR'
            }
          }
        }

        let(:sleep_record) { { bedtime: 1.hour.from_now.iso8601 } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error_code']).to eq('VALIDATION_ERROR')
        end
      end

      response(201, 'Clock-in with custom bedtime') do
        description 'Successfully creates sleep session with provided bedtime'
        schema '$ref' => '#/components/schemas/SleepRecord'

        examples 'application/json' => {
          custom_bedtime: {
            summary: 'Clock-in with specific bedtime',
            description: 'User provided a specific bedtime for the sleep session',
            value: {
              id: 2,
              user_id: 1,
              bedtime: '2024-01-15T21:00:00Z',
              wake_time: nil,
              duration_minutes: nil,
              active: true,
              created_at: '2024-01-15T21:00:00Z',
              updated_at: '2024-01-15T21:00:00Z'
            }
          }
        }

        let(:sleep_record) { { bedtime: 2.hours.ago.iso8601 } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['user_id']).to eq(test_user.id)
          expect(data['active']).to be true
          expect(data['bedtime']).to be_present
          expect(data['wake_time']).to be_nil
          expect(data['duration_minutes']).to be_nil
        end
      end

    end

    get('Get sleep history') do
      tags 'Sleep Records'
      description <<~DESC
        Retrieves the authenticated user's sleep history with pagination.

        **Query Parameters**:
        - Use `limit` and `offset` for pagination
        - Use `completed` filter to show only finished sleep sessions
        - Use `active` filter to show only ongoing sleep sessions

        **Important Notes**:
        - Results are ordered by bedtime descending (newest first)
        - Pagination info includes current_page, total_pages, and total_records
        - Both active and completed sleep sessions are returned by default

        **Workflow**:
        1. User calls this endpoint to view their sleep history
        2. System returns paginated list of sleep records for the user
        3. User can apply filters to narrow down results
      DESC
      consumes 'application/json'
      produces 'application/json'

      parameter name: 'X-USER-ID', in: :header, type: :string, required: true,
                description: 'User ID for authentication',
                example: '1'

      parameter name: :limit, in: :query, type: :integer, required: false,
                description: 'Number of records per page (max 100)',
                example: 20,
                schema: { minimum: 1, maximum: 100, default: 20 }

      parameter name: :offset, in: :query, type: :integer, required: false,
                description: 'Number of records to skip',
                example: 0,
                schema: { minimum: 0, default: 0 }

      parameter name: :completed, in: :query, type: :boolean, required: false,
                description: 'Filter for completed sessions only',
                example: true

      parameter name: :active, in: :query, type: :boolean, required: false,
                description: 'Filter for active sessions only',
                example: false

      response(200, 'Sleep history retrieved successfully') do
        description 'Returns paginated list of user sleep records'
        schema '$ref' => '#/components/schemas/SleepRecordsCollection'

        examples 'application/json' => {
          sleep_history: {
            summary: 'User sleep history',
            description: 'Paginated list of sleep records',
            value: {
              sleep_records: [
                {
                  id: 2,
                  user_id: 1,
                  bedtime: '2024-01-16T23:00:00Z',
                  wake_time: '2024-01-17T07:30:00Z',
                  duration_minutes: 510,
                  active: false,
                  created_at: '2024-01-16T23:00:00Z',
                  updated_at: '2024-01-17T07:30:00Z'
                },
                {
                  id: 1,
                  user_id: 1,
                  bedtime: '2024-01-15T22:30:00Z',
                  wake_time: nil,
                  duration_minutes: nil,
                  active: true,
                  created_at: '2024-01-15T22:30:00Z',
                  updated_at: '2024-01-15T22:30:00Z'
                }
              ],
              pagination: {
                total_count: 2,
                limit: 20,
                offset: 0,
                has_more: false
              }
            }
          }
        }

        before do
          # Create test sleep records
          test_user.sleep_records.create!(
            bedtime: 2.days.ago,
            wake_time: 2.days.ago + 8.hours
          )
          test_user.sleep_records.create!(bedtime: Time.current)
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['sleep_records']).to be_an(Array)
          expect(data['pagination']).to be_present
          expect(data['pagination']['total_count']).to be >= 0
        end
      end

    end
  end

  path '/api/v1/sleep_records/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Sleep record ID'

    patch('Clock out - End sleep session') do
      tags 'Sleep Records'
      description <<~DESC
        Ends an active sleep session (clock-out) by setting wake_time and calculating duration.

        **Important Notes**:
        - Can only be called on active sleep sessions (active=true)
        - Automatically calculates duration_minutes based on bedtime and wake_time
        - If wake_time is not provided, current timestamp is used
        - Sets active=false after successful update

        **Workflow**:
        1. User calls this endpoint with their active sleep record ID
        2. System updates the record with wake_time and duration
        3. System sets active=false to mark session as completed
      DESC
      consumes 'application/json'
      produces 'application/json'

      parameter name: 'X-USER-ID', in: :header, type: :string, required: true,
                description: 'User ID for authentication',
                example: '1'

      parameter name: :sleep_record, in: :body, required: false,
        description: 'Sleep session end data (optional)',
        schema: {
          type: :object,
          properties: {
            wake_time: {
              type: :string,
              format: :datetime,
              description: 'Custom wake time (defaults to current time)',
              example: '2024-01-16T07:30:00Z'
            }
          },
          additionalProperties: false
        }

      response(200, 'Sleep session ended successfully') do
        description 'Returns the updated sleep record with active=false and duration calculated'
        schema '$ref' => '#/components/schemas/SleepRecord'

        examples 'application/json' => {
          successful_clock_out: {
            summary: 'Successful sleep session end',
            description: 'User successfully clocked out from sleep session',
            value: {
              id: 1,
              user_id: 1,
              bedtime: '2024-01-15T22:30:00Z',
              wake_time: '2024-01-16T06:30:00Z',
              duration_minutes: 480,
              active: false,
              created_at: '2024-01-15T22:30:00Z',
              updated_at: '2024-01-16T06:30:00Z'
            }
          }
        }

        let(:sleep_record) { {} }
        let(:id) { active_sleep_record.id }
        let(:active_sleep_record) { test_user.sleep_records.create!(bedtime: 8.hours.ago) }
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['active']).to be false
          expect(data['wake_time']).to be_present
          expect(data['duration_minutes']).to be > 0
        end
      end

      response(404, 'Sleep record not found') do
        description 'Sleep record does not exist or does not belong to user'
        schema '$ref' => '#/components/schemas/Error'

        examples 'application/json' => {
          not_found: {
            summary: 'Sleep record not found',
            description: 'No sleep record exists with the provided ID for this user',
            value: {
              error: 'Sleep record not found',
              error_code: 'NOT_FOUND'
            }
          }
        }

        let(:sleep_record) { {} }
        let(:id) { 999999 }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error_code']).to eq('NOT_FOUND')
        end
      end

      response(422, 'No active sleep session') do
        description 'Sleep record exists but is not active (already completed)'
        schema '$ref' => '#/components/schemas/NoActiveSessionError'

        examples 'application/json' => {
          session_not_active: {
            summary: 'Session already completed',
            description: 'User tried to clock out from an already completed session',
            value: {
              error: 'No active sleep session found',
              error_code: 'NO_ACTIVE_SESSION'
            }
          }
        }

        let(:sleep_record) { {} }
        let(:id) { completed_sleep_record.id }
        let(:completed_sleep_record) do
          test_user.sleep_records.create!(
            bedtime: 10.hours.ago,
            wake_time: 2.hours.ago
          )
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error_code']).to eq('NO_ACTIVE_SESSION')
        end
      end

    end

    get('Get specific sleep record') do
      tags 'Sleep Records'
      description <<~DESC
        Retrieves a specific sleep record by ID for the authenticated user.

        **Access Control**:
        - Users can only access their own sleep records
        - Returns 404 if record doesn't exist or belongs to another user
      DESC
      produces 'application/json'

      parameter name: 'X-USER-ID', in: :header, type: :string, required: true,
                description: 'User ID for authentication',
                example: '1'

      response(200, 'Sleep record retrieved successfully') do
        description 'Returns the requested sleep record'
        schema '$ref' => '#/components/schemas/SleepRecord'

        let(:id) { sleep_record.id }
        let(:sleep_record) { test_user.sleep_records.create!(bedtime: 8.hours.ago) }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(sleep_record.id)
          expect(data['user_id']).to eq(test_user.id)
        end
      end

      response(404, 'Sleep record not found') do
        description 'Sleep record does not exist or does not belong to user'
        schema '$ref' => '#/components/schemas/Error'

        let(:id) { 999999 }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error_code']).to eq('NOT_FOUND')
        end
      end

    end

    delete('Delete sleep record') do
      tags 'Sleep Records'
      description <<~DESC
        Deletes a sleep record for the authenticated user.

        **Important Notes**:
        - Users can only delete their own sleep records
        - Deletion is permanent and cannot be undone
        - Returns 404 if record doesn't exist or belongs to another user
      DESC
      produces 'application/json'

      parameter name: 'X-USER-ID', in: :header, type: :string, required: true,
                description: 'User ID for authentication',
                example: '1'

      response(204, 'Sleep record deleted successfully') do
        description 'Sleep record was successfully deleted'

        let(:id) { sleep_record.id }
        let(:sleep_record) { test_user.sleep_records.create!(bedtime: 8.hours.ago) }

        run_test! do |response|
          expect(response).to have_http_status(:no_content)
          expect { sleep_record.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end

      response(404, 'Sleep record not found') do
        description 'Sleep record does not exist or does not belong to user'
        schema '$ref' => '#/components/schemas/Error'

        let(:id) { 999999 }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error_code']).to eq('NOT_FOUND')
        end
      end

    end
  end
end