require 'rate_limit'

describe 'RateLimit' do
  let(:redis_test_url) { ENV['REDIS_URL'] }

  describe '.initialize' do
    let(:key) { '123' }

    context 'when key parameter is given' do
      it 'uses the key' do
        expect(RateLimit.new(key).key).to eq key
      end
    end
    context 'when key parameter is not given' do
      it 'throws an argument error' do
        expect{ RateLimit.new }.to raise_error(ArgumentError)
      end
    end

    context 'when redis parameter is given' do
      it 'uses the parameter' do
        expect(RateLimit.new(key, 'url').redis_url).to eq 'url'
      end
    end
    context 'when redis parameter is not given' do
      it 'uses the redis url from env' do
        expect(RateLimit.new(key).redis_url).to eq redis_test_url
      end
    end
  end

  describe '#increment_request_count' do
    let(:rate_limit) { RateLimit.new('123', redis_test_url) }

    it 'increments request count value in redis' do
      expect(rate_limit.increment_request_count).to be_truthy
    end
  end

  describe '#limit_reached_and_time_to_wait' do
    let!(:chunk_size) { 900 }
    let!(:limit_duration) { 3600 }
    let!(:total_chunks) { limit_duration / chunk_size }
    let(:rate_limit) { RateLimit.new('123', redis_test_url) }
    let(:redis) { Redis.new(url: redis_rest_url) }

    before do
      rate_limit.redis.flushdb
      stub_const('RateLimit::CHUNK_SIZE', chunk_size)
      stub_const('RateLimit::TOTAL_CHUNKS', total_chunks)
      stub_const('RateLimit::LIMIT_DURATION', limit_duration)
    end

    context 'when limit is not reached' do

      it 'returns false and 0' do
        expect(rate_limit.limit_reached_and_time_to_wait).to eq([false, 0])
      end

    end

    context 'when limit is reached at chunk 0 and current chunk is 0' do
      it 'returns true and 3600 seconds to wait' do
        rate_limit.increment_request_count(0, 100)
        allow(rate_limit).to receive(:current_chunk). and_return(0)
        expect(rate_limit.limit_reached_and_time_to_wait).to eq([true, 3600])
      end
    end
    context 'when limit is reached at chunk 0 and current chunk is 3' do

      it 'returns true and 900 seconds(1 chunk_size) to wait' do
        rate_limit.increment_request_count(0, 100)
        allow(rate_limit).to receive(:current_chunk). and_return(3)
        expect(rate_limit.limit_reached_and_time_to_wait).to eq([true, 900])
      end
    end

    context 'when limit is reached at chunk 3 and current chunk is 3' do
      it 'returns true and 3600 seconds to wait' do
        rate_limit.increment_request_count(3, 100)
        allow(rate_limit).to receive(:current_chunk). and_return(3)
        expect(rate_limit.limit_reached_and_time_to_wait).to eq([true, 3600])
      end
    end

    context 'when limit is reached at chunk 2 and current chunk is 3' do
      it 'returns true and 2700 seconds to wait' do
        rate_limit.increment_request_count(2, 100)
        allow(rate_limit).to receive(:current_chunk). and_return(3)
        expect(rate_limit.limit_reached_and_time_to_wait).to eq([true, 2700])
      end
    end

    context 'when requests are distributed and limit reached at 2 and current chunk is 3' do
      it 'returns true and 900 seconds(1 chunk_size) to wait' do
        rate_limit.increment_request_count(0, 50)
        rate_limit.increment_request_count(2, 50)
        allow(rate_limit).to receive(:current_chunk). and_return(3)
        expect(rate_limit.limit_reached_and_time_to_wait).to eq([true, 900])
      end
    end
  end
end
