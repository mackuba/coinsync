require 'bigdecimal'

require_relative 'base'
require_relative '../currencies'
require_relative '../table_printer'

module CoinSync
  module Outputs
    class Summary < Base
      register_output :summary

      def requires_currency_conversion?
        false
      end

      def process_transactions(transactions, *args)
        totals = calculate_totals(transactions)

        rows = totals.map do |currency, amount|
          [
            currency.code,
            @formatter.format_crypto(amount)
          ]
        end

        printer = TablePrinter.new
        printer.print_table(['Coin', 'Amount'], rows, alignment: [:ljust, :rjust])
      end

      private

      def calculate_totals(transactions)
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

        totals
      end
    end
  end
end
