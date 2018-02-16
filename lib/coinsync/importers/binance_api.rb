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
      register_importer :binance_api

      BASE_URL = "https://api.binance.com/api"
      BASE_COINS = ['BTC', 'ETH', 'BNB', 'USDT']

      class HistoryEntry
        attr_accessor :quantity, :commission, :commission_asset, :price, :time, :buyer, :asset, :currency

        def initialize(hash)
          @quantity = BigDecimal.new(hash['qty'])
          @commission = BigDecimal.new(hash['commission'])
          @commission_asset = CryptoCurrency.new(hash['commissionAsset'])
          @price = BigDecimal.new(hash['price'])
          @time = Time.at(hash['time'] / 1000)
          @buyer = hash['isBuyer']

          @asset, @currency = parse_coins(hash['symbol'])

          if (@buyer && @commission_asset != @asset) || (!@buyer && @commission_asset != @currency)
            raise "Binance API: Unexpected fee: #{hash}"
          end
        end

        def parse_coins(symbol)
          BASE_COINS.each do |coin|
            if symbol.end_with?(coin)
              asset = symbol.gsub(/#{coin}$/, '')
              return [CryptoCurrency.new(asset), CryptoCurrency.new(coin)]
            end
          end

          raise "Binance API: Unexpected trade symbol: #{symbol}"
        end
      end

      def initialize(config, params = {})
        super

        # only "Read Info" permission is required for the key
        @api_key = params['api_key']
        @secret_key = params['secret_key']
        @traded_pairs = params['traded_pairs']
      end

      def can_import?
        !(@api_key.nil? || @secret_key.nil?)
      end

      def import_transactions(filename)
        @traded_pairs or raise "Please add a traded_pairs parameter"

        transactions = []

        @traded_pairs.uniq.each do |pair|
          response = make_request('/v3/myTrades', limit: 500, symbol: pair) # TODO: paging

          case response
          when Net::HTTPSuccess
            json = JSON.parse(response.body)

            if json.is_a?(Hash)
              raise "Kucoin importer: Invalid response: #{response.body}"
            end

            json.each { |tx| tx['symbol'] = pair }

            transactions.concat(json)
          when Net::HTTPBadRequest
            raise "Kucoin importer: Bad request: #{response} (#{response.body})"
          else
            raise "Kucoin importer: Bad response: #{response}"
          end
        end

        File.write(filename, JSON.pretty_generate(transactions.sort_by { |tx| tx['time'] }))
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
        json = JSON.parse(source.read)
        transactions = []

        json.each do |hash|
          entry = HistoryEntry.new(hash)

          if entry.buyer
            transactions << Transaction.new(
              exchange: 'Binance',
              time: entry.time,
              bought_amount: entry.quantity - entry.commission,
              bought_currency: entry.asset,
              sold_amount: entry.price * entry.quantity,
              sold_currency: entry.currency
            )
          else
            transactions << Transaction.new(
              exchange: 'Binance',
              time: entry.time,
              bought_amount: entry.price * entry.quantity - entry.commission,
              bought_currency: entry.currency,
              sold_amount: entry.quantity,
              sold_currency: entry.asset
            )
          end
        end

        transactions
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
