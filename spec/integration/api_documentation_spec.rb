require 'rails_helper'

RSpec.describe 'API Documentation Integration', type: :request do
  before do
    host! 'localhost:3000'
  end

  describe 'Documentation Generation' do
    before do
      # Generate documentation
      system('bundle exec rake rswag:specs:swaggerize')
    end

    it 'generates valid OpenAPI specification' do
      expect(File.exist?('swagger/v1/swagger.yaml')).to be true

      spec = YAML.load_file('swagger/v1/swagger.yaml')
      expect(spec['openapi']).to eq('3.0.1')
      expect(spec['info']['title']).to eq('Bedtime API V1')
      expect(spec['paths']).not_to be_empty
    end

    it 'documents existing endpoints' do
      spec = YAML.load_file('swagger/v1/swagger.yaml')
      expect(spec['paths'].keys).to include('/api/v1/users')
    end

    it 'includes proper error schemas' do
      spec = YAML.load_file('swagger/v1/swagger.yaml')
      expect(spec['components']['schemas']).to include('Error')
      expect(spec['components']['schemas']).to include('ValidationError')
      expect(spec['components']['schemas']).to include('User')
    end

    it 'includes Phase 2 template schemas' do
      spec = YAML.load_file('swagger/v1/swagger.yaml')
      expect(spec['components']['schemas']).to include('SleepRecord')
      expect(spec['components']['schemas']).to include('SleepRecordsCollection')
      expect(spec['components']['schemas']).to include('ClockInRequest')
      expect(spec['components']['schemas']).to include('ClockOutRequest')
      expect(spec['components']['schemas']).to include('ActiveSessionError')
      expect(spec['components']['schemas']).to include('NoActiveSessionError')
    end
  end

  describe 'API Specification Access' do
    it 'serves the OpenAPI specification' do
      get '/api-docs/v1/swagger.yaml', headers: { 'Host' => 'localhost:3000' }
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('text/yaml')
    end
  end

  describe 'Documentation Validation' do
    before do
      system('bundle exec rake api_docs:generate > /dev/null 2>&1')
    end

    it 'passes validation checks' do
      result = system('bundle exec rake api_docs:validate > /dev/null 2>&1')
      expect(result).to be true
    end

    it 'validates documented examples work correctly' do
      # Test successful user creation example
      post '/api/v1/users',
           params: { user: { name: 'Integration Test User' } }.to_json,
           headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:created)
      data = JSON.parse(response.body)
      expect(data['name']).to eq('Integration Test User')

      # Test validation error example
      post '/api/v1/users',
           params: { user: { name: '' } }.to_json,
           headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:unprocessable_entity)
      data = JSON.parse(response.body)
      expect(data['error_code']).to eq('VALIDATION_ERROR')
    end

    it 'validates Phase 1.5 integration is complete' do
      spec = YAML.load_file('swagger/v1/swagger.yaml')

      # Should have comprehensive user documentation
      user_endpoint = spec['paths']['/api/v1/users']['post']
      expect(user_endpoint['responses'].keys).to include('201', '422', '400')

      # Should have Phase 2 templates ready
      expect(spec['components']['schemas']['SleepRecord']).to be_present
      expect(spec['components']['securitySchemes']['user_id_header']).to be_present

      # Should have proper API info
      expect(spec['info']['title']).to eq('Bedtime API V1')
      expect(spec['openapi']).to eq('3.0.1')
    end
  end
end
