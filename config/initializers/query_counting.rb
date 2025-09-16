if Rails.env.development?
  ActiveSupport::Notifications.subscribe('sql.active_record') do |name, start, finish, id, payload|
    # Skip schema queries and cached queries
    unless payload[:name] == 'SCHEMA' || payload[:cached]
      Thread.current[:query_count] = (Thread.current[:query_count] || 0) + 1
      Thread.current[:queries] ||= []
      Thread.current[:queries] << payload[:sql]
    end
  end
end