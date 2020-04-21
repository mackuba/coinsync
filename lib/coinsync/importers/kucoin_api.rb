require 'base64'
require 'bigdecimal'
require 'json'
require 'openssl'
require 'uri'

require_relative 'base'
require_relative '../balance'
require_relative '../currencies'
require_relative '../request'
require_relative '../transaction'

module CoinSync
  module Importers
    class KucoinAPI < Base
      register_importer :kucoin_api

      BASE_URL = "https://api.kucoin.com"
      OK_CODE = "200000"

      class HistoryEntry
        attr_accessor :created_at, :amount, :direction, :coin, :base_asset, :deal_value, :fee

        def initialize(hash)
          @created_at = Time.at(hash['createdAt'])
          @amount = BigDecimal.new(hash['amount'])
          @direction = hash['side']
          @coin = CryptoCurrency.new(hash['symbol'].split('-')[0])
          @base_asset = CryptoCurrency.new(hash['symbol'].split('-')[1])
          @deal_value = BigDecimal.new(hash['dealValue'])
          @fee = BigDecimal.new(hash['fee'])
        end
      end

      def initialize(config, params = {})
        super

        # only "General" permission is required for the key
        @api_key = params['api_key']
        @api_secret = params['api_secret']
        @api_passphrase = params['api_passphrase']
      end

      def can_import?(type)
        @api_key && @api_secret && [:balances, :transactions].include?(type)
      end

      def import_transactions(filename)
        transactions = []

        ['orders', 'hist-orders'].each do |group|
          page = 1

          loop do
            json = make_request("/api/v1/#{group}", currentPage: page, pageSize: 100)

            if json['code'] != OK_CODE || json['data'].nil?
              raise "Kucoin importer: Invalid response: #{json}"
            end

            items = json['data']['items']

            if !items
              raise "Kucoin importer: No data returned: #{json}"
            end

            transactions.concat(items)

            break if items.empty?

            page += 1
          end
        end

        File.write(filename, JSON.pretty_generate(transactions) + "\n")
      end

      def import_balances
        json = make_request('/api/v1/accounts')

        if json['code'] != OK_CODE || json['data'].nil?
          raise "Kucoin importer: Invalid response: #{json}"
        end

        balances = json['data']

        balances.map { |b|
          Balance.new(
            CryptoCurrency.new(b['currency']),
            available: BigDecimal.new(b['available']),
            locked: BigDecimal.new(b['holds'])
          )
        }.reject { |b|
          b.available == 0 && b.locked == 0
        }.group_by(&:currency).map { |currency, list|
          list.inject { |sum, b| sum + b }
        }
      end

      def read_transaction_list(source)
        json = JSON.parse(source.read)
        transactions = []

        json.each do |hash|
          entry = HistoryEntry.new(hash)

          if entry.direction == 'buy'
            transactions << Transaction.new(
              exchange: 'Kucoin',
              time: entry.created_at,
              bought_amount: entry.amount - entry.fee,
              bought_currency: entry.coin,
              sold_amount: entry.deal_value,
              sold_currency: entry.base_asset
            )
          elsif entry.direction == 'sell'
            transactions << Transaction.new(
              exchange: 'Kucoin',
              time: entry.created_at,
              sold_amount: entry.amount,
              sold_currency: entry.coin,
              bought_amount: entry.deal_value - entry.fee,
              bought_currency: entry.base_asset
            )
          else
            raise "Kucoin importer error: unexpected entry direction '#{entry.direction}'"
          end
        end

        transactions.reverse
      end

      private

      def make_request(endpoint, params = {})
        (@api_key && @api_secret && @api_passphrase) or raise "Public & secret keys and a passhprase must be provided"

        timestamp = (Time.now.to_f * 1000).to_i
        url = URI(BASE_URL + endpoint)

        unless params.empty?
          url.query = build_query_string(params)
        end

        string_to_hash = [timestamp, 'GET', endpoint, url.query ? "?#{url.query}" : ""].map(&:to_s).join
        hmac = OpenSSL::HMAC.digest('sha256', @api_secret, string_to_hash)
        signature = Base64.encode64(hmac).strip

        Request.get_json(url) do |request|
          request['KC-API-KEY'] = @api_key
          request['KC-API-SIGN'] = signature
          request['KC-API-TIMESTAMP'] = timestamp
          request['KC-API-PASSPHRASE'] = @api_passphrase
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
