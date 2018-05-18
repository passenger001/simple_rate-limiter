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
    redis.multi do
      redis.hincrby(key, chunk, value)
      redis.expire(key, LIMIT_DURATION)
    end
  end

  # @return [Boolean, Fixnum]
  #
  # If count has not reached max requests: [false, 0]
  # If count has reached max requests: [true, ttl-of-key]
  def limit_reached_and_time_to_wait
    time_to_wait = 0
    count = 0

    redis.hmget(key, *(0..TOTAL_CHUNKS - 1)).each_with_index do |value, index|
     count += value.to_i
     time_to_wait = redis.ttl(key) if count == MAX_REQUESTS
    end

    return count == MAX_REQUESTS, time_to_wait
  end

  # @return [Fixnum] -> position of the current chunk in the total chunk cycle
  def current_chunk
    ((Time.now.to_i % LIMIT_DURATION) / CHUNK_SIZE).floor
  end

  # @return [Redis] -> returns the redis client
  def redis
    @redis ||= Redis.new(url: redis_url)
  end
end