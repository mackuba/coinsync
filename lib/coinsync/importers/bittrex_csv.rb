require 'bigdecimal'
require 'csv'
require 'time'

require_relative 'base'
require_relative '../currencies'
require_relative '../transaction'

module CoinSync
  module Importers
    class BittrexCSV < Base
      register_importer :bittrex_csv

      class HistoryEntry
        TIME_FORMAT = '%m/%d/%Y %H:%M:%S %p %z'

        attr_accessor :uuid, :currency, :asset, :type, :quantity, :limit, :commission, :price,
          :time_opened, :time_closed

        def initialize(line)
          @uuid = line[0]
          @currency, @asset = line[1].split('-').map { |c| CryptoCurrency.new(c) }
          @type = line[2]
          @quantity = BigDecimal.new(line[3])
          @limit = BigDecimal.new(line[4])
          @commission = BigDecimal.new(line[5])
          @price = BigDecimal.new(line[6])
          @time_opened = Time.strptime(line[7] + ' +0000', TIME_FORMAT)
          @time_closed = Time.strptime(line[8] + ' +0000', TIME_FORMAT)
        end
      end

      def read_transaction_list(source)
        contents = source.read.gsub("\u0000", '').gsub("\r", '')
        entries = []
        transactions = []

        CSV.parse(contents, col_sep: ',') do |line|
          next if line[0] == 'OrderUuid'

          entries << HistoryEntry.new(line)
        end

        entries.sort_by! { |e| [e.time_closed, e.uuid] }

        entries.each do |entry|
          case entry.type
          when 'LIMIT_BUY', 'MARKET_BUY' then
            transactions << Transaction.new(
              exchange: 'Bittrex',
              time: entry.time_closed,
              bought_amount: entry.quantity,
              bought_currency: entry.asset,
              sold_amount: entry.price + entry.commission,
              sold_currency: entry.currency
            )
          when 'LIMIT_SELL', 'MARKET_SELL' then
            transactions << Transaction.new(
              exchange: 'Bittrex',
              time: entry.time_closed,
              bought_amount: entry.price - entry.commission,
              bought_currency: entry.currency,
              sold_amount: entry.quantity,
              sold_currency: entry.asset
            )
          else
            raise "Bittrex importer error: unexpected entry type '#{entry.type}'"
          end
        end

        transactions
      end
    end
  end
end
