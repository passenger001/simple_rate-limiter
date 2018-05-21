# Simple rate limiter

## What
A simple rate limiter implementation using Rails 5.1 and Redis 3.0

## Why

>Create a new controller, perhaps called "home", with an index method. This should return only the text string "ok".

>The challenge is to implement rate limiting on this route. Limit it such that a requester can only make 100 requests per hour. After the limit has been reached, return a 429 with the text "Rate limit exceeded. Try again in #{n} seconds".

Challenge accepted.

## How

Making use of concepts from consistent hashing, we store request counts in buckets or chunks arranged in a circle (or between the numbers in a clock/watch).

By performing modulo operation on current time in seconds by 3600 seconds (`Time.now.to_i % 3600`), we can get the current second of the hour.
We then divide this by 'chunk size' to get the current chunk.

The current chunk spans a few seconds and any requests received during these seconds, updates its request count. 

The storage structure need not be too complex and would require regular integer increments and expiration. Relational DBs would be overkill with unnecessary overhead. Redis is perfectly suited for this.

Request details and chunks are all stored in Redis as a hash structure like:

`Request_IP: { chunk_number0: request_count, chunk_number1: request_count,.... chunk_numberN: request_count }` 

## Steps to get it running

Add your redis url to `.env.dev` to run it locally and `.env.test` to get it running with rspec

- Run `bundle`
- Start `rails s`
- Visit `http://localhost:3000/home` to get status 200 with an 'OK' text
- More than 100 requests in the same hour will return a status 409 with 'Rate limit exceeded. Try again in #{n} seconds' - where n is a countdown in seconds to the 1 hour wait time.
- Run `rspec` after updating `.env.test` that tests all the cases
