require 'json'
require 'net/http'
require 'uri'

require_relative 'version'

module CoinSync
  class APIError < StandardError; end

  module Request
    def self.logging_enabled
      @logging_enabled
    end

    def self.logging_enabled=(enabled)
      @logging_enabled = enabled
    end

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

    def self.retry(n)
      # TODO: list types of errors to catch
      (n-1).times do
        begin
          yield
          return
        rescue
          next
        end
      end

      yield
    end

    private

    def self.request(url, request_type)
      url = URI(url) if url.is_a?(String)

      Net::HTTP.start(url.host, url.port, use_ssl: true) do |http|
        request = request_type.new(url)
        request['User-Agent'] = "coinsync/#{CoinSync::VERSION}"
        puts ">> #{url}" if Request.logging_enabled

        yield request if block_given?

        http.request(request)
      end
    end

    def self.request_text(url, request_type, &block)
      response = request(url, request_type, &block)
      code_message = (response.message.to_s.empty?) ? response.code.to_s : "#{response.code} #{response.message}"

      case response
      when Net::HTTPSuccess
        response.body
      when Net::HTTPBadRequest
        raise APIError, "Bad request: [#{code_message}] #{response.body}"
      else
        raise APIError, "Bad response: [#{code_message}] #{response.body}"
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
