class HomeController < ApplicationController
  require 'rate_limit'

  def index
    limit_exceeded, remaining_time = rate_limit_reached
    if limit_exceeded
      render status: 429, plain: "Rate limit exceeded. Try again in #{remaining_time} seconds"
    else
      render plain: 'OK'
    end
  end

  private

  # @return [Boolean, Fixnum]
  #
  # If limit was not reached, request counter is incremented and [false, 0] is returned
  # If limit was reached: [true, time_to_wait] is returned
  def rate_limit_reached
    rate_limit = ::RateLimit.new(request.ip.to_s)
    limit_reached, time_to_wait = rate_limit.limit_reached_and_time_to_wait
    @rate_limit.increment_count unless limit_reached

    return limit_reached, time_to_wait
  end
end
