module DocumentationHelper
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def document_error_responses
      response(400, 'Bad Request') do
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      response(401, 'Unauthorized') do
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      response(404, 'Not Found') do
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      response(422, 'Unprocessable Entity') do
        schema '$ref' => '#/components/schemas/ValidationError'
        run_test!
      end

      response(500, 'Internal Server Error') do
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end
end
