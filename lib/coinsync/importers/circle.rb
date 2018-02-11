require 'bigdecimal'
require 'csv'
require 'time'

require_relative 'base'
require_relative '../currencies'
require_relative '../transaction'

module CoinSync
  module Importers
    class Circle < Base
      register_as :circle

      class HistoryEntry
        attr_accessor :date, :id, :type, :from_account, :to_account, :from_amount, :from_currency,
          :to_amount, :to_currency, :status

        def initialize(line)
          @date = Time.strptime(line[0], '%a %b %d %Y %H:%M:%S GMT+0000 (%Z)')
          @id = line[1]
          @type = line[2]
          @from_account = line[3]
          @to_account = line[4]
          @from_amount = BigDecimal.new(line[5].gsub(/[^\d\.]+/, ''))
          @from_currency = FiatCurrency.new(line[6])
          @to_amount = BigDecimal.new(line[7].gsub(/[^\d\.]+/, ''))
          @to_currency = CryptoCurrency.new(line[8])
          @status = line[9]
        end
      end

      def read_transaction_list(source)
        csv = CSV.new(source, col_sep: ',')

        transactions = []

        csv.each do |line|
          next if line[0] == 'Date'

          entry = HistoryEntry.new(line)

          next if entry.type != 'deposit'

          transactions << Transaction.new(
            exchange: 'Circle',
            bought_currency: entry.to_currency,
            sold_currency: entry.from_currency,
            time: entry.date,
            bought_amount: entry.to_amount,
            sold_amount: entry.from_amount
          )
        end

        transactions
      end
    end
  end
end
