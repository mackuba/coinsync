require 'bigdecimal'
require 'csv'
require 'time'

require_relative 'base'
require_relative '../currencies'
require_relative '../transaction'

module CoinSync
  module Importers
    # Look up your transactions using DeltaBalances at https://deltabalances.github.io/history.html,
    # specifying the time range you need, and then download the "Default" CSV in the top-right section

    class EtherDelta < Base
      register_importer :etherdelta

      ETH = CryptoCurrency.new('ETH')

      class HistoryEntry
        attr_accessor :type, :trade, :token, :amount, :price, :total, :date, :fee, :fee_token

        def initialize(line)
          @type = line[0]

          if !['Maker', 'Taker'].include?(@type)
            raise "EtherDelta importer: incorrect csv format - unexpected '#{@type}' in the first column"
          end

          @trade = line[1]

          if !['Buy', 'Sell'].include?(@trade)
            raise "EtherDelta importer: incorrect csv format - unexpected '#{@trade}' in the second column"
          end

          @token = CryptoCurrency.new(line[2])

          @amount = BigDecimal.new(line[3])
          @price = BigDecimal.new(line[4])
          @total = BigDecimal.new(line[5])
          
          @date = Time.parse(line[6])

          @fee = BigDecimal.new(line[11])
          @fee_token = CryptoCurrency.new(line[12])
        end
      end

      def read_transaction_list(source)
        csv = CSV.new(source, col_sep: ',')

        transactions = []

        csv.each do |line|
          next if line[0] == 'Type'

          entry = HistoryEntry.new(line)

          next if entry.amount.round(8) == 0 || entry.total.round(8) == 0

          if entry.trade == 'Buy'
            if entry.fee_token != ETH
              raise "EtherDelta importer: Unexpected fee currency: #{entry.fee_token.code}"
            end

            transactions << Transaction.new(
              exchange: 'EtherDelta',
              time: entry.date,
              bought_amount: entry.amount,
              bought_currency: entry.token,
              sold_amount: entry.total + entry.fee,
              sold_currency: ETH
            )
          else
            if entry.fee_token != entry.token
              raise "EtherDelta importer: Unexpected fee currency: #{entry.fee_token.code}"
            end

            transactions << Transaction.new(
              exchange: 'EtherDelta',
              time: entry.date,
              bought_amount: entry.total,
              bought_currency: ETH,
              sold_amount: entry.amount + entry.fee,
              sold_currency: entry.token
            )
          end
        end

        transactions.sort_by(&:time)
      end
    end
  end
end
