require 'rails_helper'

RSpec.describe 'API Documentation Integration', type: :request do
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
  end
  
  describe 'API Specification Access' do
    it 'serves the OpenAPI specification' do
      get '/api-docs/v1/swagger.yaml', headers: { 'Host' => 'localhost:3000' }
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('text/yaml')
    end
  end
end