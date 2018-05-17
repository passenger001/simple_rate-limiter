require 'redis'
require 'active_support'
require 'active_support/core_ext/object'
require 'dotenv'
Dotenv.load('.env.dev')

class RateLimit
  LIMIT_DURATION = 3600

  # DECREASE this value to get more accurate remaining time display but comparatively slower performance
  # CHUNK_SIZE = 1 updates the remaining time every second depending on the request
  CHUNK_SIZE = 300

  MAX_REQUESTS = 100
  TOTAL_CHUNKS = LIMIT_DURATION / CHUNK_SIZE

  attr_reader :key, :redis_url, :current_chunk, :total_chunks

  # @param [String] key -> unique identifier. In this case: IP address of the request
  # @param [String] redis_url -> redis url or defaults to the one specified in  env
  def initialize(key, redis_url = nil)
    @key = key
    @redis_url = (redis_url || ENV['REDIS_URL'])
  end

  # @param [Integer] chunk -> chunk at which the request number is stored
  # @param [Integer] value -> number of requests to be stored
  def increment_request_count(chunk = current_chunk, value = 1)
    redis.hincrby(key, chunk, value)
    redis.expire(key, LIMIT_DURATION)
  end

  # @return [Boolean, Fixnum]
  #
  # If count has not reached max requests: [false, 0] is returned
  # If count has reached max requests: [true, time_to_wait] is returned
  #
  # Gets all ordered chunks and their values. If their values add up to MAX_REQUESTS,
  # index of the 100th chunk tells us how far we have travelled from the current chunk.
  # Subtracting this index from the total chunks gives us the remaining chunks that user has to wait through
  # to make the next valid request.
  def limit_reached_and_time_to_wait
    time_to_wait = 0
    count = 0

    redis.hmget(key, *ordered_chunks).each_with_index do |value, index|
     count += value.to_i
      if count == MAX_REQUESTS
        remaining_chunks = TOTAL_CHUNKS - index
        time_to_wait = remaining_chunks * CHUNK_SIZE
        break
      end
    end

    return count == MAX_REQUESTS, time_to_wait
  end

  # @return [Fixnum] -> position of the current chunk in the total chunk cycle
  def current_chunk
    ((Time.now.to_i % LIMIT_DURATION) / CHUNK_SIZE).floor
  end

  # Get all chunks ordered from current moving all the way back in reverse covering all chunks
  def ordered_chunks
    (0..TOTAL_CHUNKS - 1).map { |i| (current_chunk - i) % TOTAL_CHUNKS }
  end

  # @return [Redis] -> returns the redis client
  def redis
    @redis ||= Redis.new(url: redis_url)
  end
end