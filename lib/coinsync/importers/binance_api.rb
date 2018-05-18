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

      def can_import?(type)
        @api_key && @secret_key && [:balances, :transactions].include?(type)
      end

      def import_transactions(filename)
        @traded_pairs or raise "Please add a traded_pairs parameter"

        transactions = []

        @traded_pairs.uniq.each do |pair|
          lastId = 0

          loop do
            json = make_request('/v3/myTrades', limit: 500, fromId: lastId + 1, symbol: pair)

            if !json.is_a?(Array)
              raise "Binance importer: Invalid response: #{json}"
            elsif json.empty?
              break
            else
              json.each { |tx| tx['symbol'] = pair }
              lastId = json.map { |j| j['id'] }.sort.last

              transactions.concat(json)
            end
          end
        end

        File.write(filename, JSON.pretty_generate(transactions.sort_by { |tx| [tx['time'], tx['id']] }))
      end

      def import_balances
        json = make_request('/v3/account')

        if json['code'] || !json['balances']
          raise "Binance importer: Invalid response: #{json}"
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
      end

      define_wrapper_command do
        summary 'Binance API importer'
      end

      define_command :find_all_pairs do
        summary 'scans all available trading pairs and finds those which you have traded before'
        description "Unfortunately, the Binance API currently doesn't allow loading transaction " +
          "history for all pairs in one go, and checking all possible pairs would take too much time, " +
          "so you need to explicitly specify the list of pairs to be downloaded in the config file. " +
          "This task helps you collect that list by scanning all available trading pairs. It may take " +
          "about 5-10 minutes to complete, that's why this isn't done automatically during the import."

        run do |opts, args, cmd|
          info = make_request('/v1/exchangeInfo', {}, false)
          found = []

          info['symbols'].each do |data|
            symbol = data['symbol']
            trades = make_request('/v3/myTrades', limit: 1, symbol: symbol)

            if trades.length > 0
              print '*'
              found << symbol
            else
              print '.'
            end
          end

          puts
          puts "Trading pairs found:"
          puts found.sort
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

      def make_request(path, params = {}, signed = true)
        print '.'

        if signed
          (@api_key && @secret_key) or raise "Public and secret API keys must be provided"

          params['timestamp'] = (Time.now.to_f * 1000).to_i
        end

        url = URI(BASE_URL + path)
        url.query = URI.encode_www_form(params)

        if signed
          hmac = OpenSSL::HMAC.hexdigest('sha256', @secret_key, url.query)
          url.query += "&signature=#{hmac}"
        end

        Request.get_json(url) do |request|
          request['X-MBX-APIKEY'] = @api_key
        end
      end
    end
  end
end
