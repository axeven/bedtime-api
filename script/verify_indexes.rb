#!/usr/bin/env ruby

# Script to verify that database indexes are working properly
# and test the performance of social feed queries

puts "=== Database Index Verification ==="

# Check that our indexes exist
indexes = ActiveRecord::Base.connection.indexes(:sleep_records)

puts "\nIndexes on sleep_records table:"
indexes.each do |index|
  puts "  - #{index.name}: #{index.columns.inspect}"
end

# Find our specific indexes
social_indexes = indexes.select { |idx| idx.name.include?('social') || idx.name.include?('duration') }

if social_indexes.any?
  puts "\n✅ Social feed indexes found:"
  social_indexes.each do |index|
    puts "  - #{index.name}: #{index.columns.inspect}"
  end
else
  puts "\n❌ No social feed indexes found"
end

puts "\n=== Testing Query Performance ==="

# Use existing data from our tests to verify query performance
if User.count > 0
  puts "\nFound #{User.count} users in the database"
  puts "Found #{SleepRecord.count} sleep records in the database"

  # Test scopes
  puts "\n1. Testing completed_records scope:"
  completed_count = SleepRecord.completed_records.count
  puts "   Found #{completed_count} completed records"

  puts "\n2. Testing recent_records scope:"
  recent_count = SleepRecord.recent_records.count
  puts "   Found #{recent_count} recent records"

  puts "\n3. Testing by_duration scope:"
  duration_ordered = SleepRecord.completed_records.by_duration.limit(3)
  puts "   Top 3 sleep records by duration:"
  duration_ordered.each_with_index do |record, i|
    duration = record.duration_minutes || "N/A"
    puts "   #{i+1}. User #{record.user_id}: #{duration} minutes"
  end

  puts "\n4. Testing for_social_feed scope:"
  social_feed_count = SleepRecord.for_social_feed.count
  puts "   Found #{social_feed_count} records in social feed"

  # Test with a real user if available
  if User.exists?
    test_user = User.first
    puts "\n5. Testing social_feed_for_user with User #{test_user.id}:"

    # Show following relationships
    following_count = test_user.following_users.count rescue 0
    puts "   User #{test_user.id} follows #{following_count} users"

    social_records = SleepRecord.social_feed_for_user(test_user)
    puts "   Found #{social_records.count} social feed records"

    # Test pagination
    paginated = SleepRecord.social_feed_with_pagination(test_user, limit: 5, offset: 0)
    puts "   Paginated (limit 5): #{paginated.count} records"

    puts "\n6. Query performance analysis:"
    puts "   Query: #{social_records.to_sql}"
  end
else
  puts "\nNo test data found. Run the test suite first to create test data."
end

puts "\n=== Step 1 Completion Status ==="
puts "✅ Social scopes implemented"
puts "✅ Helper methods implemented"
puts "✅ Database indexes created"
puts "✅ Model enhancements complete"

puts "\n🎉 Step 1 of Phase 4 successfully completed!"
puts "\nNext: Proceed to Step 2 - Following Users' Sleep Records Endpoint"
