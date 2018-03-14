require 'base64'
require 'bigdecimal'
require 'json'
require 'net/http'
require 'openssl'
require 'uri'

require_relative 'base'
require_relative 'kraken_common'
require_relative '../balance'
require_relative '../currencies'
require_relative '../request'

module CoinSync
  module Importers
    class KrakenAPI < Base
      register_importer :kraken_api

      include Kraken::Common

      BASE_URL = "https://api.kraken.com"
      API_RENEWAL_INTERVAL = 3.0

      def initialize(config, params = {})
        super
        @api_key = params['api_key']
        @secret_api_key = params['private_key']
        @decoded_secret = Base64.decode64(@secret_api_key) if @secret_api_key
      end

      def can_import?
        !(@api_key.nil? || @secret_api_key.nil?)
      end

      def import_transactions(filename)
        offset = 0
        entries = []
        slowdown = false

        loop do
          response = make_request('/0/private/Ledgers', ofs: offset)
          print slowdown ? '-' : '.'
          sleep(2 * API_RENEWAL_INTERVAL) if slowdown   # rate limiting

          case response
          when Net::HTTPSuccess
            json = JSON.parse(response.body)

            if json['result'].nil? || json['error'].length > 0
              if json['error'].first == 'EAPI:Rate limit exceeded'
                slowdown = true
                print '!'
                sleep(4 * API_RENEWAL_INTERVAL)
                next
              else
                raise "Kraken importer: Invalid response: #{response.body}"
              end
            end

            data = json['result']
            list = data && data['ledger']

            if !list
              raise "Kraken importer: No data returned: #{response.body}"
            end

            break if list.empty?

            entries.concat(list.values)
            offset += list.length
          when Net::HTTPBadRequest
            raise "Kraken importer: Bad request: #{response.body}"
          else
            raise "Kraken importer: Bad response: #{response.body}"
          end
        end

        File.write(filename, JSON.pretty_generate(entries) + "\n")
      end

      def import_balances
        response = make_request('/0/private/Balance')

        case response
        when Net::HTTPSuccess
          json = JSON.parse(response.body)

          if !json['error'].empty? || !json['result']
            raise "Kraken importer: Invalid response: #{response.body}"
          end

          return json['result'].map { |k, v|
            Balance.new(CryptoCurrency.new(k), available: BigDecimal.new(v))
          }.select { |b|
            b.available > 0
          }
        when Net::HTTPBadRequest
          raise "Kraken importer: Bad request: #{response.body}"
        else
          raise "Kraken importer: Bad response: #{response.body}"
        end
      end

      def read_transaction_list(source)
        json = JSON.parse(source.read)

        build_transaction_list(json.map { |hash| Kraken::LedgerEntry.from_json(hash) })
      end

      private

      def make_request(path, params = {})
        (@api_key && @secret_api_key) or raise "Public and secret API keys must be provided"

        nonce = (Time.now.to_f * 1000).to_i

        url = URI(BASE_URL + path)
        params['nonce'] = nonce

        post_data = URI.encode_www_form(params)
        string_to_hash = path + OpenSSL::Digest.new('sha256', nonce.to_s + post_data).digest
        hmac = Base64.strict_encode64(OpenSSL::HMAC.digest('sha512', @decoded_secret, string_to_hash))

        Request.post(url) do |request|
          request.body = post_data
          request['API-Key'] = @api_key
          request['API-Sign'] = hmac
        end
      end
    end
  end
end
