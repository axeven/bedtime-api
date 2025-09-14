module SleepRecordSchemas
  def self.sleep_record_schema
    {
      type: :object,
      properties: {
        id: {
          type: :integer,
          description: 'Unique sleep record identifier',
          example: 1
        },
        user_id: {
          type: :integer,
          description: 'ID of the user who owns this sleep record',
          example: 1
        },
        bedtime: {
          type: :string,
          format: :datetime,
          description: 'When the user went to bed (clock-in time)',
          example: '2024-01-15T22:30:00Z'
        },
        wake_time: {
          type: :string,
          format: :datetime,
          description: 'When the user woke up (clock-out time). Null for active sessions.',
          example: '2024-01-16T07:30:00Z',
          nullable: true
        },
        duration_minutes: {
          type: :integer,
          description: 'Total sleep duration in minutes. Null for active sessions.',
          example: 540,
          minimum: 0,
          nullable: true
        },
        active: {
          type: :boolean,
          description: 'Whether this is an active sleep session (user has not woken up yet)',
          example: false
        },
        created_at: {
          type: :string,
          format: :datetime,
          description: 'Record creation timestamp',
          example: '2024-01-15T22:30:00Z'
        },
        updated_at: {
          type: :string,
          format: :datetime,
          description: 'Record last update timestamp',
          example: '2024-01-16T07:30:00Z'
        }
      },
      required: [ 'id', 'user_id', 'bedtime', 'active', 'created_at', 'updated_at' ],
      additionalProperties: false
    }
  end

  def self.sleep_records_collection_schema
    {
      type: :object,
      properties: {
        sleep_records: {
          type: :array,
          description: 'Array of sleep records',
          items: { '$ref' => '#/components/schemas/SleepRecord' }
        },
        pagination: {
          type: :object,
          description: 'Pagination information',
          properties: {
            total_count: {
              type: :integer,
              description: 'Total number of sleep records for this user',
              example: 25,
              minimum: 0
            },
            limit: {
              type: :integer,
              description: 'Maximum number of records returned in this response',
              example: 20,
              minimum: 1,
              maximum: 100
            },
            offset: {
              type: :integer,
              description: 'Number of records skipped',
              example: 0,
              minimum: 0
            },
            has_more: {
              type: :boolean,
              description: 'Whether there are more records available',
              example: true
            }
          },
          required: [ 'total_count', 'limit', 'offset', 'has_more' ],
          additionalProperties: false
        }
      },
      required: [ 'sleep_records', 'pagination' ],
      additionalProperties: false
    }
  end

  def self.clock_in_request_schema
    {
      type: :object,
      properties: {
        bedtime: {
          type: :string,
          format: :datetime,
          description: 'Custom bedtime (optional - defaults to current time)',
          example: '2024-01-15T22:30:00Z'
        }
      },
      additionalProperties: false,
      example: {
        bedtime: '2024-01-15T22:30:00Z'
      }
    }
  end

  def self.clock_out_request_schema
    {
      type: :object,
      properties: {
        wake_time: {
          type: :string,
          format: :datetime,
          description: 'Custom wake time (optional - defaults to current time)',
          example: '2024-01-16T07:30:00Z'
        }
      },
      additionalProperties: false,
      example: {
        wake_time: '2024-01-16T07:30:00Z'
      }
    }
  end

  def self.active_session_error_schema
    {
      type: :object,
      properties: {
        error: {
          type: :string,
          description: 'Error message',
          example: 'You already have an active sleep session'
        },
        error_code: {
          type: :string,
          description: 'Error code for programmatic handling',
          example: 'ACTIVE_SESSION_EXISTS'
        },
        details: {
          type: :object,
          description: 'Additional error context',
          properties: {
            active_session_id: {
              type: :integer,
              description: 'ID of the existing active session',
              example: 5
            },
            active_since: {
              type: :string,
              format: :datetime,
              description: 'When the active session started',
              example: '2024-01-15T22:30:00Z'
            }
          },
          required: [ 'active_session_id' ],
          additionalProperties: false
        }
      },
      required: [ 'error', 'error_code', 'details' ],
      additionalProperties: false
    }
  end

  def self.no_active_session_error_schema
    {
      type: :object,
      properties: {
        error: {
          type: :string,
          description: 'Error message',
          example: 'No active sleep session found'
        },
        error_code: {
          type: :string,
          description: 'Error code for programmatic handling',
          example: 'NO_ACTIVE_SESSION'
        }
      },
      required: [ 'error', 'error_code' ],
      additionalProperties: false
    }
  end
end
