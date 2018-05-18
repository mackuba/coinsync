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
    class GateIO < Base
      register_importer :gateio

      BASE_URL = "https://api.gate.io/api2/1"

      class HistoryEntry
        attr_accessor :trade_id, :order_number, :pair, :asset, :currency, :type, :rate, :amount, :total, :time

        def initialize(hash)
          @trade_id = hash['trade_id']
          @order_number = hash['order_number']
          @pair = hash['pair']
          @asset, @currency = @pair.split('_').map { |c| CryptoCurrency.new(c.upcase) }
          @type = hash['type']
          @rate = BigDecimal.new(hash['rate'])
          @amount = BigDecimal.new(hash['amount'])
          @total = BigDecimal.new(hash['total'], 0)
          @time = Time.at(hash['time_unix'])
        end
      end

      def initialize(config, params = {})
        super
        @api_key = params['key']
        @api_secret = params['secret']
        @traded_pairs = params['traded_pairs']
      end

      def can_import?(type)
        @api_key && @api_secret && [:balances, :transactions].include?(type)
      end

      def import_transactions(filename)
        @traded_pairs or raise "Please add a traded_pairs parameter"

        transactions = []

        @traded_pairs.uniq.each do |pair|
          json = make_request('/private/tradeHistory', currencyPair: pair)

          if json['result'] != 'true' || !json['trades']
            raise "Gate.io importer: Invalid response: #{json}"
          end

          transactions.concat(json['trades'])
        end

        File.write(filename, JSON.pretty_generate(transactions.sort_by { |tx| [tx['time_unix'], tx['tradeId']] }))
      end

      def import_balances
        json = make_request('/private/balances')

        if json['result'] != 'true' || !json['available']
          raise "Gate.io importer: Invalid response: #{json}"
        end

        symbols = ['available', 'locked'].map { |f| json[f].select { |k, v| v.to_f > 0 }.keys }.flatten.uniq

        symbols.map do |s|
          Balance.new(
            CryptoCurrency.new(s.upcase),
            available: BigDecimal.new(json['available'][s] || '0'),
            locked: BigDecimal.new(json['locked'][s] || '0')
          )
        end
      end

      def find_all_pairs
        pairs = make_request('/pairs', {}, false)
        found = []

        pairs.each do |pair|
          json = make_request('/private/tradeHistory', currencyPair: pair)

          if json['result'] != 'true' || !json['trades']
            raise "Gate.io importer: Invalid response: #{json}"
          end

          if json['trades'].length > 0
            print '*'
            found << pair
          else
            print '.'
          end
        end

        puts
        puts "Trading pairs found:"
        puts found.sort
      end

      def read_transaction_list(source)
        json = JSON.parse(source.read)
        transactions = []

        json.each do |hash|
          entry = HistoryEntry.new(hash)

          if entry.type == 'buy'
            transactions << Transaction.new(
              exchange: 'Gate.io',
              time: entry.time,
              bought_amount: entry.amount,
              bought_currency: entry.asset,
              sold_amount: entry.total,
              sold_currency: entry.currency
            )
          elsif entry.type == 'sell'
            transactions << Transaction.new(
              exchange: 'Gate.io',
              time: entry.time,
              sold_amount: entry.amount,
              sold_currency: entry.asset,
              bought_amount: entry.total,
              bought_currency: entry.currency
            )
          else
            raise "Gate.io importer error: unexpected entry type '#{entry.type}'"
          end
        end

        transactions.reverse
      end


      private

      def make_request(path, params = {}, signed = true)
        if signed
          (@api_key && @api_secret) or raise "Public and secret API keys must be provided"

          nonce = (Time.now.to_f * 1000).to_i
          params['nonce'] = nonce
        end

        url = URI(BASE_URL + path)
        param_string = URI.encode_www_form(params)

        if signed
          hmac = OpenSSL::HMAC.hexdigest('sha512', @api_secret, param_string)

          Request.post_json(url) do |request|
            request.body = param_string
            request['KEY'] = @api_key
            request['SIGN'] = hmac
          end
        else
          url.query = param_string
          Request.get_json(url)
        end
      end
    end
  end
end
