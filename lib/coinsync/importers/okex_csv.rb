require 'bigdecimal'
require 'csv'
require 'time'

require_relative 'base'
require_relative '../currencies'
require_relative '../transaction'

module CoinSync
  module Importers
    class OkexCSV < Base
      register_importer :okex_csv

      MAX_TIME_DIFFERENCE = 3.0

      class HistoryEntry
        attr_accessor :time, :type, :size, :balance, :fee, :currency

        def initialize(line)
          @time = Time.parse(line[0].gsub(/ CST/, ' +0800'))  # srsly?...
          @type = line[1]
          @size = BigDecimal.new(line[2], 0)
          @balance = BigDecimal.new(line[3], 0)
          @fee = BigDecimal.new(line[4], 0)
          @currency = CryptoCurrency.new(line[5])
        end
      end

      def read_transaction_list(source)
        csv = CSV.new(source, col_sep: ',')

        entries = []
        transactions = []
        set = []

        csv.each do |line|
          next if line[1] == 'type'

          entries << HistoryEntry.new(line)
        end

        entries.each do |entry|
          set << entry
          next unless set.length == 2

          if (set[0].time - set[1].time).abs > MAX_TIME_DIFFERENCE
            raise "Okex importer error: Couldn't match a pair of history lines - too big time difference: #{set}"
          end

          bought = set.detect { |e| e.type == 'buy' }
          sold = set.detect { |e| e.type == 'sell' }

          if bought.nil? || sold.nil?
            raise "Okex importer error: Couldn't match a pair of history lines - unexpected types: #{set}"
          end

          transactions << Transaction.new(
            exchange: 'Okex',
            time: [bought.time, sold.time].max,
            bought_amount: bought.size + bought.fee,
            bought_currency: bought.currency,
            sold_amount: -(sold.size + sold.fee),
            sold_currency: sold.currency
          )

          set.clear
        end

        if !set.empty?
          raise "Okex importer error: unmatched transaction: #{set}"
        end

        transactions.reverse
      end
    end
  end
end
