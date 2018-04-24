require 'json'
require 'net/http'

require_relative 'base'
require_relative '../request'

module CoinSync
  module CurrencyConverters
    class ExchangeRatesAPI < Base
      register_converter :exchangeratesapi

      BASE_URL = "https://exchangeratesapi.io/api"

      class Exception < StandardError; end
      class NoDataException < Exception; end
      class BadRequestException < Exception; end

      def fetch_conversion_rate(from:, to:, date:)
        response = Request.get("#{BASE_URL}/#{date}?base=#{from.code}")

        case response
        when Net::HTTPSuccess
          json = JSON.parse(response.body)
          rate = json['rates'][to.code.upcase]
          raise NoDataException.new("No exchange rate found for #{to.code.upcase}") if rate.nil?

          return rate
        when Net::HTTPBadRequest
          raise BadRequestException.new(response)
        else
          raise Exception.new(response)
        end
      end
    end
  end
end
