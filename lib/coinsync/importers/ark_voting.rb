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

      BASE_URL = "https://explorer.ark.io/api"
      ARK = CryptoCurrency.new('ARK')

      class HistoryEntry
        attr_accessor :timestamp, :amount, :recipient, :payments

        def initialize(hash)
          @timestamp = Time.at(hash['timestamp']['unix'])
          @amount = BigDecimal.new(hash['amount']) / 100_000_000
          @recipient = hash['recipient']

          if hash['asset']
            if payments = hash['asset']['payments']
              @payments = payments.map { |p| [p['recipientId'], BigDecimal.new(p['amount']) / 100_000_000] }.to_h
            end
          end
        end
      end

      def initialize(config, params = {})
        super
        @address = params['address']
      end

      def can_import?(type)
        @address && [:balances, :transactions].include?(type)
      end

      def delegates
        @delegates ||= load_delegates
      end

      def import_transactions(filename)
        page = 1
        transactions = []

        loop do
          json = make_request("/wallets/#{@address}/transactions", orderBy: 'timestamp:desc', page: page)

          if !json['meta'] || !json['data']
            raise "Ark importer: Invalid response: #{json}"
          end

          rewards = json['data'].select { |tx| tx['sender'] != @address && delegates.include?(tx['sender']) }
          rewards.each { |r| r.delete('confirmations') }
          transactions.concat(rewards)

          break if json['data'].empty? || !json['meta']['next']

          page += 1
        end

        File.write(filename, JSON.pretty_generate(transactions.reverse) + "\n")
      end

      def import_balances
        json = make_request("/wallets/#{@address}")

        if !json['data'] || !json['data']['balance']
          raise "Ark importer: Invalid response: #{json}"
        end

        [Balance.new(ARK, available: BigDecimal.new(json['data']['balance']) / 100_000_000)]
      end

      def read_transaction_list(source)
        json = JSON.parse(source.read)
        transactions = []

        json.each do |hash|
          entry = HistoryEntry.new(hash)

          amount = (entry.recipient == @address) ? entry.amount : entry.payments[@address]

          transactions << Transaction.new(
            exchange: 'Ark voting',
            time: entry.timestamp,
            bought_amount: amount,
            bought_currency: ARK,
            sold_amount: BigDecimal.new(0),
            sold_currency: FiatCurrency.new(nil)
          )
        end

        transactions
      end

      private

      def load_delegates
        page = 1
        delegates = []

        loop do
          json = make_request("/delegates", page: page)

          if !json['meta'] || !json['data']
            raise "Ark importer: Invalid response: #{json}"
          end

          addresses = json['data'].map { |j| j['address'] }
          delegates.concat(addresses)

          break if json['data'].empty? || !json['meta']['next']

          page += 1
        end

        delegates
      end

      def make_request(path, params = {})
        url = URI(BASE_URL + path)
        url.query = URI.encode_www_form(params)

        Request.get_json(url)
      end
    end
  end
end
