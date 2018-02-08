require 'bigdecimal'

require_relative '../currencies'
require_relative '../formatter'
require_relative '../table_printer'

module CoinSync
  module Outputs
    class Summary
      def initialize(config)
        @config = config
        @formatter = Formatter.new(@config)
      end

      def process_transactions(transactions)
        totals = Hash.new { BigDecimal(0) }

        transactions.each do |tx|
          if tx.bought_currency.crypto?
            amount = totals[tx.bought_currency]
            totals[tx.bought_currency] = amount + tx.bought_amount
          end

          if tx.sold_currency.crypto?
            amount = totals[tx.sold_currency]
            if amount >= tx.sold_amount
              totals[tx.sold_currency] = amount - tx.sold_amount
            else
              raise "Summary: couldn't sell #{@formatter.format_crypto(tx.sold_amount)} #{tx.sold_currency.code} " +
                "if only #{@formatter.format_crypto(amount)} was owned"
            end
          end
        end

        rows = totals.map do |currency, amount|
          [
            currency.code,
            @formatter.format_crypto(amount)
          ]
        end

        printer = TablePrinter.new
        printer.print_table(['Coin', 'Amount'], rows, alignment: [:ljust, :rjust])
      end
    end
  end
end
