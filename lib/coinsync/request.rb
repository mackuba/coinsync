require 'net/http'
require 'uri'

module CoinSync
  module Request
    def self.get(url, &block)
      self.request(url, Net::HTTP::Get, &block)
    end

    def self.post(url, &block)
      self.request(url, Net::HTTP::Post, &block)
    end

    private

    def self.request(url, request_type)
      url = URI(url) if url.is_a?(String)

      Net::HTTP.start(url.host, url.port, use_ssl: true) do |http|
        request = request_type.new(url)

        yield request if block_given?

        http.request(request)
      end
    end
  end
end
