require 'csv'

require_relative 'base'
require_relative '../formatter'

module CoinSync
  module Outputs
    class Raw < Base
      register_output :raw

      def process_transactions(transactions, *args)
        CSV.open(@target_file, 'w', col_sep: @config.column_separator) do |csv|
          csv << headers

          transactions.each do |tx|
            csv << transaction_to_csv(tx)
          end
        end
      end

      def headers
        [
          'Exchange',
          'Date',
          'Bought amount',
          'Bought currency',
          'Sold amount',
          'Sold currency'
        ]
      end

      def transaction_to_csv(tx)
        [
          tx.exchange,
          @formatter.format_time(tx.time),
          tx.bought_currency.crypto? ?
            @formatter.format_crypto(tx.bought_amount) : @formatter.format_fiat(tx.bought_amount),
          tx.bought_currency.code,
          tx.sold_currency.crypto? ?
            @formatter.format_crypto(tx.sold_amount) : @formatter.format_fiat(tx.sold_amount),
          tx.sold_currency.code
        ]
      end
    end
  end
end
