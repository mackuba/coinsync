require 'json'
require 'net/http'

module CoinSync
  module CurrencyConverters
    class Fixer
      BASE_URL = "https://api.fixer.io"

      class Exception < StandardError; end
      class NoDataException < Exception; end
      class BadRequestException < Exception; end

      def convert(amount, from:, to:, date:)
        url = URI("#{BASE_URL}/#{date}?base=#{from}")
        response = Net::HTTP.get_response(url)

        case response
        when Net::HTTPSuccess
          json = JSON.load(response.body)
          rate = json['rates'][to.upcase]
          raise NoDataException.new("No exchange rate found for #{to.upcase}") if rate.nil?

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
