require 'bigdecimal'
require 'csv'
require 'time'

require_relative 'base'
require_relative '../currencies'
require_relative '../formatter'
require_relative '../transaction'

module CoinSync
  module Importers
    class Default < Base
      register_importer :default

      class HistoryEntry
        attr_accessor :lp, :exchange, :type, :date, :amount, :asset, :total, :currency
      end

      def initialize(config, params = {})
        super
        @decimal_separator = config.custom_decimal_separator
        @formatter = Formatter.new(config)
      end

      def read_transaction_list(source)
        csv = CSV.new(source, col_sep: @config.column_separator)

        transactions = []

        csv.each do |line|
          next if line.empty?
          next if line.all? { |f| f.to_s.strip == '' }
          next if line[0] == 'Lp'

          entry = parse_line(line)

          if entry.type.downcase == Transaction::TYPE_PURCHASE.to_s
            transactions << Transaction.new(
              exchange: entry.exchange,
              bought_currency: entry.asset,
              sold_currency: entry.currency,
              time: entry.date,
              bought_amount: entry.amount,
              sold_amount: entry.total
            )
          elsif entry.type.downcase == Transaction::TYPE_SALE.to_s
            transactions << Transaction.new(
              exchange: entry.exchange,
              bought_currency: entry.currency,
              sold_currency: entry.asset,
              time: entry.date,
              bought_amount: entry.total,
              sold_amount: entry.amount
            )
          else
            raise "Default importer error: unexpected entry type '#{entry.type}'"
          end
        end

        transactions
      end

      private

      def parse_line(line)
        entry = HistoryEntry.new

        entry.lp = line[0].to_i
        entry.exchange = line[1]
        entry.type = line[2]

        time = Time.parse(line[3])
        entry.date = @config.timezone ? @config.timezone.local_to_utc(time) : time

        entry.amount = @formatter.parse_decimal(line[4])
        entry.asset = CryptoCurrency.new(line[5])
        entry.total = @formatter.parse_decimal(line[6])

        entry.currency = if line[7].to_s.start_with?('$')
          CryptoCurrency.new(line[7][1..-1])
        else
          FiatCurrency.new(line[7])
        end

        if entry.currency.code.nil? && entry.total > 0
          raise "Default importer error: Currency must be specified if total value is non-zero"
        end

        entry
      end
    end
  end
end
