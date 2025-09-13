namespace :api_docs do
  desc "Generate API documentation"
  task generate: :environment do
    puts "Generating API documentation..."

    # Run rswag specs to generate documentation
    system("bundle exec rake rswag:specs:swaggerize")

    if File.exist?('swagger/v1/swagger.yaml')
      puts "✅ API documentation generated successfully!"
      puts "📄 View at: http://localhost:3000/api-docs"
    else
      puts "❌ Failed to generate API documentation"
      exit 1
    end
  end

  desc "Validate API documentation"
  task validate: :environment do
    puts "Validating API documentation..."

    if File.exist?('swagger/v1/swagger.yaml')
      require 'yaml'
      begin
        doc = YAML.load_file('swagger/v1/swagger.yaml')

        # Basic validation
        raise "Missing info section" unless doc['info']
        raise "Missing paths section" unless doc['paths']
        raise "No endpoints documented" if doc['paths'].empty?

        puts "✅ API documentation validation passed!"
        puts "📊 Documented endpoints: #{doc['paths'].keys.count}"
      rescue => e
        puts "❌ API documentation validation failed: #{e.message}"
        exit 1
      end
    else
      puts "❌ No API documentation found"
      exit 1
    end
  end

  desc "Generate and validate API documentation"
  task update: ['api_docs:generate', 'api_docs:validate']
end