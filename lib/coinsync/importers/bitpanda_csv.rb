require 'bigdecimal'
require 'csv'
require 'time'

require_relative 'base'
require_relative '../currencies'
require_relative '../transaction'

module CoinSync
  module Importers
    class BitpandaCSV < Base
      register_importer :bitpanda_csv

      class HistoryEntry
        attr_accessor :type, :date, :amount, :currency, :price, :price_currency, :fee, :fee_currency

        def initialize(line)
          @type = line[2]

          @amount = BigDecimal.new(line[4])
          @currency = parse_currency(line[5])

          @price = BigDecimal.new(line[6])
          @price_currency = parse_currency(line[7])

          @fee = BigDecimal.new(line[8])
          @fee_currency = parse_currency(line[9])

          @date = Time.parse(line[10])
        end

        def parse_currency(code)
          case code
          when 'BTC' then CryptoCurrency.new('BTC')
          when 'EUR' then FiatCurrency.new('EUR')
          else raise "Unknown currency: #{code}"
          end
        end
      end

      def read_transaction_list(source)
        content = source.read.gsub(/\r\n/, "\n")
        csv = CSV.new(content, col_sep: ',')

        transactions = []

        csv.each do |line|
          next if line.empty?
          next if line[2].to_s.empty? || line[2] == 'Type'

          entry = HistoryEntry.new(line)

          if entry.type == 'SELL'
            if entry.price_currency != entry.fee_currency
              raise "Bitpanda importer error: price and fee currency don't match"
            end

            transactions << Transaction.new(
              exchange: 'Bitpanda',
              bought_currency: entry.price_currency,
              sold_currency: entry.currency,
              time: entry.date,
              bought_amount: entry.price * entry.amount - entry.fee,
              sold_amount: entry.amount
            )
          else
            raise "Bitpanda importer error: not implemented yet"
          end
        end

        transactions
      end
    end
  end
end
