require 'bigdecimal'
require 'json'
require 'net/http'
require 'time'
require 'uri'

require_relative 'base'
require_relative '../balance'
require_relative '../currencies'
require_relative '../request'
require_relative '../transaction'

module CoinSync
  module Importers
    class LiskVoting < Base
      register_importer :lisk_voting

      BASE_URL = "https://explorer.lisk.io/api"
      EPOCH_TIME = Time.parse('2016-05-24 17:00 UTC')
      LISK = CryptoCurrency.new('LSK')

      class HistoryEntry
        attr_accessor :timestamp, :amount

        def initialize(hash)
          @timestamp = EPOCH_TIME + hash['timestamp']
          @amount = BigDecimal.new(hash['amount']) / 100_000_000
        end
      end

      def initialize(config, params = {})
        super
        @address = params['address']
      end

      def can_import?
        !!@address
      end

      def import_transactions(filename)
        response = make_request('/getTransactionsByAddress', address: @address, limit: 1000)

        case response
        when Net::HTTPSuccess
          json = JSON.parse(response.body)

          if json['success'] != true || !json['transactions']
            raise "Lisk importer: Invalid response: #{response.body}"
          end

          rewards = json['transactions'].select { |tx| tx['senderDelegate'] }

          File.write(filename, JSON.pretty_generate(rewards) + "\n")
        when Net::HTTPBadRequest
          raise "Lisk importer: Bad request: #{response}"
        else
          raise "Lisk importer: Bad response: #{response}"
        end
      end

      def import_balances
        response = make_request('/getAccount', address: @address)

        case response
        when Net::HTTPSuccess
          json = JSON.parse(response.body)

          if json['success'] != true || !json['balance']
            raise "Lisk importer: Invalid response: #{response.body}"
          end

          [Balance.new(LISK, available: BigDecimal.new(json['balance']) / 100_000_000)]
        when Net::HTTPBadRequest
          raise "Lisk importer: Bad request: #{response}"
        else
          raise "Lisk importer: Bad response: #{response}"
        end
      end

      def read_transaction_list(source)
        json = JSON.parse(source.read)
        transactions = []

        json.each do |hash|
          entry = HistoryEntry.new(hash)

          transactions << Transaction.new(
            exchange: 'Lisk voting',
            time: entry.timestamp,
            bought_amount: entry.amount,
            bought_currency: LISK,
            sold_amount: BigDecimal.new(0),
            sold_currency: FiatCurrency.new(nil)
          )
        end

        transactions.reverse
      end

      private

      def make_request(path, params = {})
        url = URI(BASE_URL + path)
        url.query = params.map { |k, v| "#{k}=#{v}" }.join('&')

        Request.get(url)
      end
    end
  end
end
