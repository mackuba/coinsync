require_relative '../currencies'
require_relative '../transaction'

module CoinSync
  module Importers
    class Default
      class HistoryEntry
        attr_accessor :lp, :exchange, :type, :date, :amount, :asset, :total, :currency
      end

      def initialize(settings = {})
        @settings = settings
        @labels = @settings['labels'] || {}
        @decimal_separator = @settings['decimal_separator']
      end

      def read_transaction_list(source)
        csv = CSV.new(source, col_sep: @settings['column_separator'] || ',')

        transactions = []

        csv.each do |line|
          next if line.empty?
          next if line.all? { |f| f.to_s.strip == '' }
          next if line[0] == 'Lp'

          entry = parse_line(line)

          if entry.type == 'Purchase'
            transactions << Transaction.new(
              exchange: entry.exchange,
              bought_currency: entry.asset,
              sold_currency: entry.currency,
              time: entry.date,
              bought_amount: entry.amount,
              sold_amount: entry.total
            )
          elsif entry.type == 'Sale'
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

      def save_to_csv(tx)
        case tx.type
        when Transaction::TYPE_PURCHASE
          amount = tx.bought_amount
          total = tx.sold_amount
          asset = tx.bought_currency.code
          currency = tx.sold_currency.code
        when Transaction::TYPE_SALE
          amount = tx.sold_amount
          total = tx.bought_amount
          asset = tx.sold_currency.code
          currency = tx.bought_currency.code
        else
          raise "Currently unsupported"
        end

        tx_type = tx.type.to_s

        [
          tx.number || 0,
          tx.exchange,
          @labels[tx_type] || tx_type.capitalize,
          tx.time,
          format_float(amount, 8),
          asset,
          format_float(total, 4),
          format_float(total / amount, 4),
          currency
        ]
      end

      private

      def parse_line(line)
        entry = HistoryEntry.new

        entry.lp = line[0].to_i
        entry.exchange = line[1]
        entry.type = line[2]
        entry.date = Time.parse(line[3])
        entry.amount = parse_float(line[4])
        entry.asset = CryptoCurrency.new(line[5])
        entry.total = parse_float(line[6])
        entry.currency = FiatCurrency.new(line[7])

        entry
      end

      def parse_float(string)
        string = string.gsub(@decimal_separator, '.') if @decimal_separator
        string.to_f
      end

      def format_float(value, prec)
        s = sprintf("%.#{prec}f", value)
        s.gsub!(/\./, @decimal_separator) if @decimal_separator
        s
      end
    end
  end
end
