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

      def can_import?(type)
        @address && [:balances, :transactions].include?(type)
      end

      def import_transactions(filename)
        offset = 0
        transactions = []

        loop do
          json = make_request('/getTransactionsByAddress', address: @address, limit: 100, offset: offset)

          if json['success'] != true || !json['transactions']
            raise "Lisk importer: Invalid response: #{json}"
          end

          list = json['transactions']
          break if list.empty?

          transactions.concat(list)
          offset += list.length
        end

        senders = transactions.map { |tx| tx['senderId'] }.uniq.sort
        delegates = senders.select { |s| check_if_delegate(s) }

        reward_transactions = transactions.select { |tx| delegates.include?(tx['senderId']) }
        reward_transactions.each { |r| r.delete('confirmations') }

        File.write(filename, JSON.pretty_generate(reward_transactions) + "\n")
      end

      def check_if_delegate(address)
        json = make_request('/getAccount', address: address)

        if json['success'] != true
          raise "Lisk importer: Invalid response: #{json}"
        end

        json['delegate'] != nil
      end

      def import_balances
        json = make_request('/getAccount', address: @address)

        if json['success'] != true || !json['balance']
          raise "Lisk importer: Invalid response: #{json}"
        end

        [Balance.new(LISK, available: BigDecimal.new(json['balance']) / 100_000_000)]
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
        url.query = URI.encode_www_form(params)

        Request.get_json(url)
      end
    end
  end
end
