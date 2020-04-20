require 'bigdecimal'
require 'csv'
require 'time'

require_relative 'base'
require_relative '../currencies'
require_relative '../transaction'

module CoinSync
  module Importers
    class BitstampCSV < Base
      register_importer :bitstamp_csv

      class HistoryEntry
        attr_accessor :type, :date, :account, :operation
        attr_accessor :amount, :currency, :fiat_amount, :fiat_currency, :fee_amount, :fee_currency

        def initialize(line)
          @type = line[0]
          @date = Time.parse(line[1] + ' +0000')
          @account = line[2]

          @amount = BigDecimal.new(line[3].split(' ').first)
          @currency = parse_currency(line[3].split(' ').last)

          if !line[4].to_s.empty?
            @fiat_amount = BigDecimal.new(line[4].split(' ').first)
            @fiat_currency = parse_currency(line[4].split(' ').last)
          end

          if !line[6].to_s.empty?
            @fee_amount = BigDecimal.new(line[6].split(' ').first)
            @fee_currency = parse_currency(line[6].split(' ').last)
          end

          @operation = line[7]
        end

        def parse_currency(code)
          case code
          when 'BTC' then CryptoCurrency.new('BTC')
          when 'EUR' then FiatCurrency.new('EUR')
          when 'USD' then FiatCurrency.new('USD')
          else raise "Unknown currency: #{code}"
          end
        end
      end

      def read_transaction_list(source)
        csv = CSV.new(source, col_sep: ',')

        transactions = []

        csv.each do |line|
          next if line.empty?
          next if line[0] == 'Type'

          entry = HistoryEntry.new(line)

          next if entry.type != 'Market'

          if entry.operation == 'Sell'
            if entry.fiat_currency != entry.fee_currency
              raise "Bitstamp importer error: received and fee currency don't match"
            end

            transactions << Transaction.new(
              exchange: 'Bitstamp',
              bought_currency: entry.fiat_currency,
              sold_currency: entry.currency,
              time: entry.date,
              bought_amount: entry.fiat_amount - entry.fee_amount,
              sold_amount: entry.amount
            )
          else
            raise "Bitstamp importer error: not implemented yet"
          end
        end

        transactions
      end
    end
  end
end
