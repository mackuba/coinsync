require 'bigdecimal'
require 'csv'
require 'time'

require_relative '../currencies'
require_relative '../transaction'

module CoinSync
  module Importers
    class Changelly
      class HistoryEntry
        attr_accessor :status, :date, :exchanged_currency, :exchanged_amount, :received_currency, :received_amount

        def initialize(line)
          @status = line[0]
          @date = Time.parse(line[1] + ' +0000')

          amount, name = line[2].gsub(',', '').split(/\s+/)
          @exchanged_currency = CryptoCurrency.new(name)
          @exchanged_amount = BigDecimal.new(amount)

          amount, name = line[6].gsub(',', '').split(/\s+/)
          @received_currency = CryptoCurrency.new(name)
          @received_amount = BigDecimal.new(amount)
        end
      end

      def read_transaction_list(source)
        csv = CSV.new(source, col_sep: ',')

        transactions = []

        csv.each do |line|
          next if line[0] == 'Status'

          entry = HistoryEntry.new(line)

          next if entry.status != 'finished'

          transactions << Transaction.new(
            exchange: 'Changelly',
            time: entry.date,
            bought_amount: entry.received_amount,
            bought_currency: entry.received_currency,
            sold_amount: entry.exchanged_amount,
            sold_currency: entry.exchanged_currency
          )
        end

        transactions.reverse
      end
    end
  end
end
