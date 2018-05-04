require 'bigdecimal'
require 'json'
require 'time'
require 'uri'

require_relative 'base'
require_relative '../balance'
require_relative '../currencies'
require_relative '../request'
require_relative '../transaction'

module CoinSync
  module Importers
    class ArkVoting < Base
      register_importer :ark_voting

      BASE_URL = "https://explorer.dafty.net/api"
      EPOCH_TIME = Time.parse('2017-03-21 13:00 UTC')
      ARK = CryptoCurrency.new('ARK')

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

      def can_import?(type)
        @address && [:balances, :transactions].include?(type)
      end

      def import_transactions(filename)
        offset = 0
        limit = 50
        transactions = []

        loop do
          json = make_request('/getTransactionsByAddress', address: @address, limit: limit, offset: offset)

          if json['success'] != true || !json['transactions']
            raise "Ark importer: Invalid response: #{response.body}"
          end

          break if json['transactions'].empty?

          rewards = json['transactions'].select { |tx| tx['senderDelegate'] }
          transactions.concat(rewards)

          offset += limit
        end

        File.write(filename, JSON.pretty_generate(transactions) + "\n")
      end

      def import_balances
        json = make_request('/getAccount', address: @address)

        if json['success'] != true || !json['balance']
          raise "Ark importer: Invalid response: #{response.body}"
        end

        [Balance.new(ARK, available: BigDecimal.new(json['balance']) / 100_000_000)]
      end

      def read_transaction_list(source)
        json = JSON.parse(source.read)
        transactions = []

        json.each do |hash|
          entry = HistoryEntry.new(hash)

          transactions << Transaction.new(
            exchange: 'Ark voting',
            time: entry.timestamp,
            bought_amount: entry.amount,
            bought_currency: ARK,
            sold_amount: BigDecimal.new(0),
            sold_currency: FiatCurrency.new(nil)
          )
        end

        transactions.reverse
      end

      private

      def make_request(path, params = {})
        url = URI(BASE_URL + path)
        url.query = URI.encode_www_form(params)

        Request.get_json(url)
      end
    end
  end
end
