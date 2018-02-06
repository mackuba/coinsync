require_relative '../currencies'
require_relative '../formatter'

module CoinSync
  module Outputs
    class Summary
      def initialize(config)
        @config = config
        @formatter = Formatter.new(@config)
      end

      def process_transactions(transactions)
        totals = Hash.new(0)

        transactions.each do |tx|
          if tx.bought_currency.is_a?(CryptoCurrency)
            amount = totals[tx.bought_currency]
            totals[tx.bought_currency] = amount + tx.bought_amount
          end

          if tx.sold_currency.is_a?(CryptoCurrency)
            amount = totals[tx.sold_currency]
            if amount >= tx.sold_amount
              totals[tx.sold_currency] = amount - tx.sold_amount
            else
              raise "Summary: couldn't sell #{tx.sold_amount} #{tx.sold_currency.code} if only #{amount} was owned"
            end
          end
        end

        max_len = totals.keys.map(&:code).map(&:length).max

        totals.each do |currency, amount|
          puts (currency.code + ":").ljust(max_len + 1) + '  ' + @formatter.format_crypto(amount)
        end
      end
    end
  end
end
