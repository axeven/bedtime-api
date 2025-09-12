#!/bin/bash
set -e

# Remove any existing server.pid
rm -f /app/tmp/pids/server.pid

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
while ! pg_isready -h $DATABASE_HOST -p 5432 -U $DATABASE_USER > /dev/null 2>&1; do
  sleep 1
done
echo "PostgreSQL is ready!"

# Wait for Redis to be ready (if REDIS_URL is set)
if [ ! -z "$REDIS_URL" ]; then
  echo "Waiting for Redis to be ready..."
  until redis-cli -u $REDIS_URL ping > /dev/null 2>&1; do
    sleep 1
  done
  echo "Redis is ready!"
fi

# Execute the container's main command
exec "$@"