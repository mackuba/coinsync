require 'bigdecimal'
require 'json'
require 'net/http'
require 'openssl'

require_relative 'base'
require_relative '../balance'
require_relative '../currencies'
require_relative '../transaction'

module CoinSync
  module Importers
    class BinanceAPI < Base
      register_as :binance_api

      BASE_URL = "https://api.binance.com/api"

      def initialize(config, params = {})
        super
        @api_key = params['api_key']
        @secret_key = params['secret_key']
      end

      def can_import?
        !(@api_key.nil? || @secret_key.nil?)
      end

      def import_transactions(filename)
        # TODO
      end

      def import_balances
        response = make_request('/v3/account')

        case response
        when Net::HTTPSuccess
          json = JSON.parse(response.body)

          if json['code'] || !json['balances']
            raise "Kucoin importer: Invalid response: #{response.body}"
          end

          return json['balances'].select { |b|
            b['free'].to_f > 0 || b['locked'].to_f > 0
          }.map { |b|
            Balance.new(
              CryptoCurrency.new(b['asset']),
              available: BigDecimal.new(b['free']),
              locked: BigDecimal.new(b['locked'])
            )
          }
        when Net::HTTPBadRequest
          raise "Kucoin importer: Bad request: #{response}"
        else
          raise "Kucoin importer: Bad response: #{response}"
        end
      end

      def read_transaction_list(source)
        # TODO
      end

      private

      def make_request(path, params = {})
        (@api_key && @secret_key) or raise "Public and secret API keys must be provided"

        params['timestamp'] = (Time.now.to_f * 1000).to_i

        url = URI(BASE_URL + path)
        url.query = params.map { |k, v| "#{k}=#{v}" }.join('&')

        hmac = OpenSSL::HMAC.hexdigest('sha256', @secret_key, url.query)
        url.query += "&signature=#{hmac}"

        Net::HTTP.start(url.host, url.port, use_ssl: true) do |http|
          request = Net::HTTP::Get.new(url)
          request['X-MBX-APIKEY'] = @api_key

          http.request(request)
        end
      end
    end
  end
end
