require 'csv'
require 'time'
require_relative '../transaction'

module CoinSync
  module Importers
    class BitBay20
      OP_PAY_BUYING = 'Pay for buying currency'
      OP_PAY_SELLING = 'Pay for selling currency'
      OP_PURCHASE = 'Currency purchase'
      OP_SALE = 'Currency sale'
      OP_FEE = 'Transaction fee'

      MAX_TIME_DIFFERENCE = 5.0

      TRANSACTION_TYPES = [OP_PAY_BUYING, OP_PAY_SELLING, OP_PURCHASE, OP_SALE, OP_FEE]

      class HistoryEntry
        attr_accessor :date, :accounting_date, :type, :amount, :currency

        def initialize(line)
          @date = Time.parse(line[0]) unless line[0] == '-'
          @accounting_date = Time.parse(line[1]) unless line[1] == '-'
          @type = line[2]

          amount, currency = line[3].split(' ')
          @amount = amount.gsub(/,/, '').to_f
          @currency = parse_currency(currency)
        end

        def crypto?
          @currency.is_a?(CryptoCurrency)
        end

        def fiat?
          @currency.is_a?(FiatCurrency)
        end

        def parse_currency(code)
          case code
          when 'BTC' then CryptoCurrency.new('BTC')
          when 'ETH' then CryptoCurrency.new('ETH')
          when 'LSK' then CryptoCurrency.new('LSK')
          when 'LTC' then CryptoCurrency.new('LTC')
          when 'PLN' then FiatCurrency.new('PLN')
          else raise "Unknown currency: #{code}"
          end
        end
      end

      def process(source)
        csv = CSV.new(source, col_sep: ';')

        matching = []
        transactions = []

        csv.each do |line|
          next if line.empty?
          next if line[0] !~ /^\d/

          entry = HistoryEntry.new(line)

          next unless TRANSACTION_TYPES.include?(entry.type)

          if !matching.empty? && matching.any? { |e| (e.date - entry.date).abs > MAX_TIME_DIFFERENCE }
            if matching.any? { |e| e.type != OP_FEE }
              raise "BitBay importer error: Couldn't match some history lines"
            else
              matching.clear
            end
          end

          matching << entry

          if matching.length == 3
            matching.sort_by!(&:type)
            types = matching.map(&:type)
            time = matching.map(&:date).sort.last

            if types == [OP_PURCHASE, OP_PAY_BUYING, OP_FEE] &&
              matching[0].crypto? && matching[0].amount > 0 &&
              matching[1].fiat? && matching[1].amount < 0 &&
              matching[2].crypto? && matching[2].amount <= 0 &&
              matching[0].currency == matching[2].currency
                transactions << Transaction.new(
                  exchange: 'BitBay',
                  bought_currency: matching[0].currency,
                  sold_currency: matching[1].currency,
                  time: time,
                  bought_amount: matching[0].amount + matching[2].amount,
                  sold_amount: -matching[1].amount
                )
            elsif types == [OP_SALE, OP_PAY_SELLING, OP_FEE] &&
              matching[0].crypto? && matching[0].amount < 0 &&
              matching[1].fiat? && matching[1].amount > 0 &&
              matching[2].fiat? && matching[2].amount <= 0 &&
              matching[1].currency == matching[2].currency
                transactions << Transaction.new(
                  exchange: 'BitBay',
                  bought_currency: matching[1].currency,
                  sold_currency: matching[0].currency,
                  time: time,
                  bought_amount: matching[1].amount + matching[2].amount,
                  sold_amount: -matching[0].amount
                )
            elsif types == [OP_PURCHASE, OP_SALE, OP_FEE] &&
              matching[0].fiat? && matching[0].amount > 0 &&
              matching[1].crypto? && matching[1].amount < 0 &&
              matching[2].fiat? && matching[2].amount <= 0 &&
              matching[0].currency == matching[2].currency
                transactions << Transaction.new(
                  exchange: 'BitBay',
                  bought_currency: matching[0].currency,
                  sold_currency: matching[1].currency,
                  time: time,
                  bought_amount: matching[0].amount + matching[2].amount,
                  sold_amount: -matching[1].amount
                )
            else
              raise "BitBay importer error: Couldn't match some history lines"
            end

            matching.clear
          end
        end

        if !matching.empty?
          if matching.any? { |l| l.type != OP_FEE }
            raise "BitBay importer error: Couldn't match some history lines"
          end
        end

        transactions
      end
    end
  end
end
