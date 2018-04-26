require 'json'
require 'net/http'
require 'uri'

require_relative 'version'

module CoinSync
  module Request
    [:get, :post].each do |method|
      define_singleton_method(method) do |url, &block|
        self.request(url, Net::HTTP.const_get(method.to_s.capitalize), &block)
      end

      define_singleton_method("#{method}_text") do |url, &block|
        self.request_text(url, Net::HTTP.const_get(method.to_s.capitalize), &block)
      end

      define_singleton_method("#{method}_json") do |url, &block|
        self.request_json(url, Net::HTTP.const_get(method.to_s.capitalize), &block)
      end
    end

    private

    def self.request(url, request_type)
      url = URI(url) if url.is_a?(String)

      Net::HTTP.start(url.host, url.port, use_ssl: true) do |http|
        request = request_type.new(url)
        request['USER_AGENT'] = "coinsync/#{CoinSync::VERSION}"

        yield request if block_given?

        http.request(request)
      end
    end

    def self.request_text(url, request_type, &block)
      response = request(url, request_type, &block)

      case response
      when Net::HTTPSuccess
        response.body
      when Net::HTTPBadRequest
        raise "Bad request: #{response}"
      else
        raise "Bad response: #{response}"
      end
    end

    def self.request_json(url, request_type, &block)
      response = request_text(url, request_type, &block)

      if response.empty?
        raise "Received empty response"
      else
        JSON.parse(response)
      end
    end
  end
end
