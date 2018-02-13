require 'base64'
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
    class KucoinAPI < Base
      register_as :kucoin_api

      BASE_URL = "https://api.kucoin.com"

      class HistoryEntry
        attr_accessor :created_at, :amount, :direction, :coin_type, :coin_type_pair, :deal_value, :fee

        def initialize(hash)
          @created_at = Time.at(hash['createdAt'] / 1000)
          @amount = BigDecimal.new(hash['amount'], 0)
          @direction = hash['direction']
          @coin_type = CryptoCurrency.new(hash['coinType'])
          @coin_type_pair = CryptoCurrency.new(hash['coinTypePair'])
          @deal_value = BigDecimal.new(hash['dealValue'], 0)
          @fee = BigDecimal.new(hash['fee'], 0)
        end
      end

      def initialize(config, params = {})
        super
        @api_key = params['api_key']
        @api_secret = params['api_secret']
      end

      def can_import?
        !(@api_key.nil? || @api_secret.nil?)
      end

      def import_transactions(filename)
        response = make_request('/order/dealt', limit: 100) # TODO: what if there's more than 100?

        case response
        when Net::HTTPSuccess
          json = JSON.parse(response.body)

          if json['success'] != true || json['code'] != 'OK'
            raise "Kucoin importer: Invalid response: #{response.body}"
          end

          data = json['data']
          list = data && data['datas']

          if !list
            raise "Kucoin importer: No data returned: #{response.body}"
          end

          File.write(filename, JSON.pretty_generate(list) + "\n")
        when Net::HTTPBadRequest
          raise "Kucoin importer: Bad request: #{response}"
        else
          raise "Kucoin importer: Bad response: #{response}"
        end
      end

      def import_balances
        page = 1
        full_list = []

        loop do
          response = make_request('/account/balances', limit: 20, page: page)

          case response
          when Net::HTTPSuccess
            json = JSON.parse(response.body)

            if json['success'] != true || json['code'] != 'OK'
              raise "Kucoin importer: Invalid response: #{response.body}"
            end

            data = json['data']
            list = data && data['datas']

            if !list
              raise "Kucoin importer: No data returned: #{response.body}"
            end

            full_list.concat(list)

            page += 1
            break if page > data['pageNos']
          when Net::HTTPBadRequest
            raise "Kucoin importer: Bad request: #{response}"
          else
            raise "Kucoin importer: Bad response: #{response}"
          end
        end

        full_list.delete_if { |b| b['balance'] == 0.0 && b['freezeBalance'] == 0.0 }

        full_list.map do |b|
          Balance.new(
            CryptoCurrency.new(b['coinType']),
            available: BigDecimal.new(b['balanceStr']),
            locked: BigDecimal.new(b['freezeBalanceStr'])
          )
        end
      end

      def read_transaction_list(source)
        json = JSON.parse(source.read)
        transactions = []

        json.each do |hash|
          entry = HistoryEntry.new(hash)

          if entry.direction == 'BUY'
            transactions << Transaction.new(
              exchange: 'Kucoin',
              time: entry.created_at,
              bought_amount: entry.amount - entry.fee,
              bought_currency: entry.coin_type,
              sold_amount: entry.deal_value,
              sold_currency: entry.coin_type_pair
            )
          else
            # TODO sell
            raise "Kucoin importer error: unexpected entry direction '#{entry.direction}'"
          end
        end

        transactions.reverse
      end

      private

      def make_request(path, params = {})
        (@api_key && @api_secret) or raise "Public and secret API keys must be provided"

        endpoint = '/v1' + path
        nonce = (Time.now.to_f * 1000).to_i
        url = URI(BASE_URL + endpoint)

        url.query = build_query_string(params)

        string_to_hash = Base64.strict_encode64("#{endpoint}/#{nonce}/#{url.query}")
        hmac = OpenSSL::HMAC.hexdigest('sha256', @api_secret, string_to_hash)

        Net::HTTP.start(url.host, url.port, use_ssl: true) do |http|
          request = Net::HTTP::Get.new(url)

          request['KC-API-KEY'] = @api_key
          request['KC-API-NONCE'] = nonce
          request['KC-API-SIGNATURE'] = hmac

          http.request(request)
        end
      end

      def build_query_string(params)
        params.map { |k, v|
          [k.to_s, v.to_s]
        }.sort_by { |k, v|
          [k[0] < 'a' ? 1 : 0, k]
        }.map { |k, v|
          "#{k}=#{v}"
        }.join('&')
      end
    end
  end
end