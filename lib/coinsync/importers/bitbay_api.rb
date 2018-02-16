require 'bigdecimal'
require 'json'
require 'net/http'
require 'openssl'
require 'time'

require_relative 'base'
require_relative '../balance'
require_relative '../currencies'
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
          @date = Time.parse(hash['time'])  # TODO: these times are all fucked up
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
          when 'BTC' then CryptoCurrency.new('BTC')
          when 'ETH' then CryptoCurrency.new('ETH')
          when 'LTC' then CryptoCurrency.new('LTC')
          when 'LSK' then CryptoCurrency.new('LSK')
          when 'BCC' then CryptoCurrency.new('BCH')
          when 'BTG' then CryptoCurrency.new('BTG')
          when 'GAME' then CryptoCurrency.new('GAME')
          when 'DASH' then CryptoCurrency.new('DASH')
          when 'PLN' then FiatCurrency.new('PLN')
          when 'EUR' then FiatCurrency.new('EUR')
          when 'USD' then FiatCurrency.new('USD')
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

      def can_import?
        !(@public_key.nil? || @secret_key.nil?)
      end

      def import_transactions(filename)
        info = fetch_info

        currencies = info['balances'].keys
        transactions = []

        currencies.each do |currency|
          sleep 1  # rate limiting

          response = make_request('history', currency: currency, limit: 10000)  # TODO: does this limit really work?

          case response
          when Net::HTTPSuccess
            json = JSON.parse(response.body)

            if !json.is_a?(Array)
              raise "BitBay API importer: Invalid response: #{response.body}"
            end

            transactions.concat(json)
          when Net::HTTPBadRequest
            raise "BitBay API importer: Bad request: #{response}"
          else
            raise "BitBay API importer: Bad response: #{response}"
          end
        end

        transactions.each_with_index { |tx, i| tx['i'] = i }
        transactions.sort_by! { |tx| [tx['time'], -tx['i']] }
        transactions.each_with_index { |tx, i| tx.delete('i') }

        File.write(filename, JSON.pretty_generate(transactions))
      end

      def import_balances
        info = fetch_info

        info['balances'].select { |k, v|
          v['available'].to_f > 0 || v['locked'].to_f > 0
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

          if !matching.empty? && matching.any? { |e| (e.date - entry.date).abs > MAX_TIME_DIFFERENCE }
            transactions << process_matched(matching)
          end

          matching << entry
        end

        if !matching.empty?
          transactions << process_matched(matching)
        end

        transactions
      end


      private

      def process_matched(matching)
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
                exchange: 'BitBay3',
                bought_currency: bought_currency.first,
                sold_currency: sold_currency.first,
                time: (purchases + sales + fees).map(&:date).last,
                bought_amount: (purchases + fees).map(&:amount).reduce(&:+),
                sold_amount: -sales.map(&:amount).reduce(&:+)
              )
            end
          end
        end

        raise "BitBay API importer error: Couldn't match some history lines: #{matching}"
      end

      def make_request(method, params = {})
        (@public_key && @secret_key) or raise "Public and secret API keys must be provided"

        url = URI(BASE_URL)

        params['method'] = method
        params['moment'] = Time.now.to_i

        param_string = params.map { |k, v| "#{k}=#{v}" }.join('&')
        hmac = OpenSSL::HMAC.hexdigest('sha512', @secret_key, param_string)

        Net::HTTP.start(url.host, url.port, use_ssl: true) do |http|
          request = Net::HTTP::Post.new(url)
          request.body = param_string

          request['API-Key'] = @public_key
          request['API-Hash'] = hmac

          http.request(request)
        end
      end

      def fetch_info
        response = make_request('info')

        case response
        when Net::HTTPSuccess
          json = JSON.parse(response.body)

          if json['success'] != 1 || json['code'] || json['balances'].nil?
            raise "BitBay API importer: Invalid response: #{response.body}"
          end

          json
        when Net::HTTPBadRequest
          raise "BitBay API importer: Bad request: #{response}"
        else
          raise "BitBay API importer: Bad response: #{response}"
        end
      end
    end
  end
end
