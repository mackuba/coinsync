require 'csv'
require 'time'

require_relative '../currencies'
require_relative '../transaction'

module CoinSync
  module Importers
    class Bitcurex
      class HistoryEntry
        attr_accessor :lp, :type, :date, :market, :amount, :price, :total, :fee, :fee_currency, :id

        def initialize(line)
          @lp = line[0].to_i
          @type = line[1]
          @date = Time.parse(line[2])
          @market = FiatCurrency.new(line[3])
          @amount = line[4].to_f
          @price = line[5].split(' ').first.to_f
          @total = line[6].split(' ').first.to_f
          @fee = line[7].split(' ').first.to_f
          @fee_currency = line[7].split(' ').last
          @id = line[8].to_i
        end
      end

      def read_transaction_list(source)
        csv = CSV.new(source, col_sep: ',')

        transactions = []
        bitcoin = CryptoCurrency.new('BTC')

        csv.each do |line|
          next if line.empty?
          next if line[0] == 'LP'

          entry = HistoryEntry.new(line)

          if entry.type == 'Kup'
            transactions << Transaction.new(
              exchange: 'Bitcurex',
              bought_currency: bitcoin,
              sold_currency: entry.market,
              time: entry.date,
              bought_amount: entry.amount,
              sold_amount: entry.total
            )
          elsif entry.type == 'Sprzedaj'
            transactions << Transaction.new(
              exchange: 'Bitcurex',
              bought_currency: entry.market,
              sold_currency: bitcoin,
              time: entry.date,
              bought_amount: entry.total,
              sold_amount: entry.amount
            )
          else
            raise "Bitcurex importer error: unexpected entry type '#{entry.type}'"
          end
        end

        transactions
      end
    end
  end
end
