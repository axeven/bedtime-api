require 'swagger_helper'

RSpec.describe 'api/v1/users', type: :request do
  before do
    host! 'localhost:3000'
  end
  path '/api/v1/users' do
    post('Create user') do
      tags 'Users'
      description 'Creates a new user for development/testing purposes'
      consumes 'application/json'
      produces 'application/json'
      
      parameter name: :user, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              name: { 
                type: :string,
                description: 'User name',
                example: 'John Doe',
                minLength: 1,
                maxLength: 100
              }
            },
            required: ['name']
          }
        },
        required: ['user']
      }

      response(201, 'User created successfully') do
        schema '$ref' => '#/components/schemas/User'

        let(:user) { { user: { name: 'Test User' } } }
        
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Test User')
          expect(data['id']).to be_present
          expect(data['created_at']).to be_present
        end
      end

      response(422, 'Validation failed') do
        schema '$ref' => '#/components/schemas/ValidationError'

        let(:user) { { user: { name: '' } } }
        
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error_code']).to eq('VALIDATION_ERROR')
          expect(data['details']['name']).to include("can't be blank")
        end
      end

      response(400, 'Bad request - missing parameters') do
        schema '$ref' => '#/components/schemas/Error'

        let(:user) { {} }
        
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error_code']).to eq('BAD_REQUEST')
          expect(data['error']).to include('param is missing')
        end
      end
    end
  end
end