require 'bigdecimal'
require 'json'
require 'openssl'
require 'time'
require 'tzinfo'
require 'uri'

require_relative 'base'
require_relative '../balance'
require_relative '../currencies'
require_relative '../request'
require_relative '../transaction'

module CoinSync
  module Importers
    class BitBayAPI < Base
      register_importer :bitbay_api

      BASE_URL = "https://bitbay.net/API/Trading/tradingApi.php"

      OP_PURCHASE = '+currency_transaction'
      OP_SALE = '-pay_for_currency'
      OP_FEE = '-fee'

      MAX_TIME_DIFFERENCE = 5.0
      TRANSACTION_TYPES = [OP_PURCHASE, OP_SALE, OP_FEE]

      class HistoryEntry
        attr_accessor :date, :amount, :type, :currency

        def initialize(hash)
          @date = Time.parse(hash['time'] + ' +0000')
          @amount = BigDecimal.new(hash['amount'])
          @type = hash['operation_type']
          @currency = parse_currency(hash['currency'])
        end

        def crypto?
          @currency.crypto?
        end

        def fiat?
          @currency.fiat?
        end

        def parse_currency(code)
          case code.upcase

          when 'BCC' then CryptoCurrency.new('BCH')
          when 'BTC' then CryptoCurrency.new('BTC')
          when 'BTG' then CryptoCurrency.new('BTG')
          when 'DASH' then CryptoCurrency.new('DASH')
          when 'ETH' then CryptoCurrency.new('ETH')
          when 'GAME' then CryptoCurrency.new('GAME')
          when 'KZC' then CryptoCurrency.new('KZC')
          when 'LSK' then CryptoCurrency.new('LSK')
          when 'LTC' then CryptoCurrency.new('LTC')
          when 'XIN' then CryptoCurrency.new('XIN')
          when 'XRP' then CryptoCurrency.new('XRP')

          when 'EUR' then FiatCurrency.new('EUR')
          when 'USD' then FiatCurrency.new('USD')
          when 'PLN' then FiatCurrency.new('PLN')

          else raise "Unknown currency: #{code}"
          end
        end
      end

      def initialize(config, params = {})
        super

        # required permissions:
        # * for balance checks:
        #   - "Crypto deposit" (shown as "Get and create cryptocurrency addresses" + "Funds deposit")
        #   - "Updating a wallets list" (shown as "Pobieranie rachunków")
        # * for transaction history:
        #   - "History" (shown as "Fetch history of transactions")

        @public_key = params['api_public_key']
        @secret_key = params['api_private_key']
      end

      def can_import?(type)
        @public_key && @secret_key && [:balances, :transactions].include?(type)
      end

      def import_transactions(filename)
        info = fetch_info

        currencies = info['balances'].keys
        transactions = []

        currencies.each do |currency|
          sleep 1  # rate limiting

          # TODO: does this limit really work? (no way to test it really and docs don't mention a max value)
          json = make_request('history', currency: currency, limit: 10000)

          if !json.is_a?(Array)
            raise "BitBay API importer: Invalid response: #{json}"
          end

          transactions.concat(json)
        end

        transactions.each_with_index { |tx, i| tx['i'] = i }
        transactions.sort_by! { |tx| [tx['time'], -tx['i']] }
        transactions.each_with_index { |tx, i| tx.delete('i') }

        File.write(filename, JSON.pretty_generate(transactions))
      end

      def import_balances
        info = fetch_info

        info['balances'].select { |k, v|
          (v['available'].to_f > 0 || v['locked'].to_f > 0) && !(['PLN', 'EUR', 'USD'].include?(k))
        }.map { |k, v|
          Balance.new(
            CryptoCurrency.new(k),
            available: BigDecimal.new(v['available']),
            locked: BigDecimal.new(v['locked'])
          )
        }
      end

      def read_transaction_list(source)
        json = JSON.parse(source.read)

        matching = []
        transactions = []

        json.each do |hash|
          entry = HistoryEntry.new(hash)

          next unless TRANSACTION_TYPES.include?(entry.type)

          if !matching.empty?
            must_match = matching.any? { |e| (e.date - entry.date).abs > MAX_TIME_DIFFERENCE }
            transaction = process_matched(matching, must_match)
            transactions << transaction if transaction
          end

          matching << entry
        end

        if !matching.empty?
          transactions << process_matched(matching, true)
        end

        transactions
      end


      private

      def process_matched(matching, must_match)
        if matching.length % 3 == 0
          purchases = matching.select { |tx| tx.type == OP_PURCHASE }
          sales = matching.select { |tx| tx.type == OP_SALE }
          fees = matching.select { |tx| tx.type == OP_FEE }

          if purchases.length == sales.length && purchases.length == fees.length
            bought_currency = (purchases + fees).map(&:currency).uniq
            sold_currency = sales.map(&:currency).uniq

            if bought_currency.length == 1 && sold_currency.length == 1
              matching.clear

              return Transaction.new(
                exchange: 'BitBay',
                bought_currency: bought_currency.first,
                sold_currency: sold_currency.first,
                time: (purchases + sales + fees).map(&:date).last,
                bought_amount: (purchases + fees).map(&:amount).reduce(&:+),
                sold_amount: -sales.map(&:amount).reduce(&:+)
              )
            end
          end
        end

        if must_match
          raise "BitBay API importer error: Couldn't match some history lines: " +
            matching.map { |m| "\n#{m.inspect}" }.join
        end
      end

      def make_request(method, params = {})
        (@public_key && @secret_key) or raise "Public and secret API keys must be provided"

        url = URI(BASE_URL)

        params['method'] = method
        params['moment'] = Time.now.to_i

        param_string = URI.encode_www_form(params)
        hmac = OpenSSL::HMAC.hexdigest('sha512', @secret_key, param_string)

        Request.post_json(url) do |request|
          request.body = param_string
          request['API-Key'] = @public_key
          request['API-Hash'] = hmac
        end
      end

      def fetch_info
        json = make_request('info')

        if json['success'] != 1 || json['code'] || json['balances'].nil?
          raise "BitBay API importer: Invalid response: #{json}"
        end

        json
      end
    end
  end
end
