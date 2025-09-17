module QueryCountable
  extend ActiveSupport::Concern

  included do
    around_action :log_query_count, if: -> { Rails.env.development? }
  end

  private

  def log_query_count
    count_before = query_count
    queries_before = capture_queries

    start_time = Time.current
    yield
    end_time = Time.current

    count_after = query_count
    queries_after = capture_queries

    query_diff = count_after - count_before
    duration = ((end_time - start_time) * 1000).round(2)

    Rails.logger.info "PERFORMANCE [#{request.method} #{request.path}]: #{duration}ms, #{query_diff} queries"

    if query_diff > 10
      Rails.logger.warn "HIGH QUERY COUNT: #{query_diff} queries detected"
      new_queries = queries_after - queries_before
      new_queries.each_with_index do |query, index|
        Rails.logger.warn "Query #{index + 1}: #{query}"
      end
    end
  end

  def query_count
    Thread.current[:query_count] ||= 0
  end

  def capture_queries
    Thread.current[:queries] ||= []
  end

  def reset_query_tracking
    Thread.current[:query_count] = 0
    Thread.current[:queries] = []
  end
end
