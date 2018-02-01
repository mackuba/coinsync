require 'json'
require 'net/http'

module CoinSync
  module CurrencyConverters
    class Fixer
      BASE_URL = "https://api.fixer.io"

      class Exception < StandardError; end
      class NoDataException < Exception; end
      class BadRequestException < Exception; end

      def initialize
        @rates = {}
      end

      def convert(amount, from:, to:, date:)
        @rates[from] ||= {}
        return @rates[from][date] * amount if @rates[from][date]

        url = URI("#{BASE_URL}/#{date}?base=#{from.code}")
        response = Net::HTTP.get_response(url)

        case response
        when Net::HTTPSuccess
          json = JSON.load(response.body)
          rate = json['rates'][to.code.upcase]
          raise NoDataException.new("No exchange rate found for #{to.code.upcase}") if rate.nil?

          @rates[from][date] = rate

          return rate * amount
        when Net::HTTPBadRequest
          raise BadRequestException.new(response)
        else
          raise Exception.new(response)
        end
      end
    end
  end
end
