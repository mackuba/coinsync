require 'json'
require 'net/http'

require_relative 'base'

module CoinSync
  module CurrencyConverters
    class NBP < Base
      BASE_URL = "https://api.nbp.pl/api"

      class Exception < StandardError; end
      class NoDataException < Exception; end
      class BadRequestException < Exception; end

      def fetch_conversion_rate(from:, to:, date:)
        raise "Only conversions to PLN are supported" if to.code != 'PLN'

        url = URI("#{BASE_URL}/exchangerates/rates/a/#{from.code}/#{date - 1}/?format=json")
        response = Net::HTTP.get_response(url)

        case response
        when Net::HTTPSuccess
          json = JSON.load(response.body)
          rate = json['rates'] && json['rates'][0] && json['rates'][0]['mid']
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
