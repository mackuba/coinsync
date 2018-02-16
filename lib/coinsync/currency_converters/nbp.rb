require 'json'
require 'net/http'

require_relative 'base'

module CoinSync
  module CurrencyConverters
    class NBP < Base
      register_converter :nbp

      BASE_URL = "https://api.nbp.pl/api"

      class Exception < StandardError; end
      class NoDataException < Exception; end
      class BadRequestException < Exception; end

      def fetch_conversion_rate(from:, to:, date:)
        raise "Only conversions to PLN are supported" if to.code != 'PLN'

        url = URI("#{BASE_URL}/exchangerates/rates/a/#{from.code}/#{date - 8}/#{date - 1}/?format=json")
        response = Net::HTTP.get_response(url)

        case response
        when Net::HTTPSuccess
          json = JSON.parse(response.body)
          rate = json['rates'] && json['rates'].last && json['rates'].last['mid']
          raise NoDataException.new("No exchange rate found for #{from.code.upcase}") if rate.nil?

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
