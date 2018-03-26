require 'bigdecimal'
require 'json'
require 'net/http'
require 'openssl'
require 'uri'

require_relative 'base'
require_relative '../balance'
require_relative '../currencies'
require_relative '../request'

module CoinSync
  module Importers
    class BittrexAPI < Base
      register_importer :bittrex_api

      BASE_URL = "https://bittrex.com/api/v1.1"

      def initialize(config, params = {})
        super

        # only "Read Info" permission is required for the key
        @api_key = params['api_key']
        @api_secret = params['api_secret']
      end

      def can_import?(type)
        @api_key && @api_secret && [:balances].include?(type)
      end

      def can_build?
        false
      end

      def import_balances
        response = make_request('/account/getbalances')

        case response
        when Net::HTTPSuccess
          json = JSON.parse(response.body)

          if json['success'] != true || !json['result']
            raise "Bittrex importer: Invalid response: #{response.body}"
          end

          return json['result'].select { |b|
            b['Balance'] > 0
          }.map { |b|
            Balance.new(
              CryptoCurrency.new(b['Currency']),
              available: BigDecimal.new(b['Available'], 0),
              locked: BigDecimal.new(b['Balance'], 0) - BigDecimal.new(b['Available'], 0)
            )
          }
        when Net::HTTPBadRequest
          raise "Bittrex importer: Bad request: #{response}"
        else
          raise "Bittrex importer: Bad response: #{response}"
        end
      end

      private

      def make_request(path, params = {})
        (@api_key && @api_secret) or raise "Public and secret API keys must be provided"

        params['apikey'] = @api_key
        params['nonce'] = (Time.now.to_f * 1000).to_i

        url = URI(BASE_URL + path)
        url.query = URI.encode_www_form(params)

        hmac = OpenSSL::HMAC.hexdigest('sha512', @api_secret, url.to_s)

        Request.get(url) do |request|
          request['apisign'] = hmac
        end
      end
    end
  end
end
