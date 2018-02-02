require 'csv'

module CoinSync
  module Outputs
    class Default
      def initialize(config, target_file)
        @config = config
        @target_file = target_file
        @labels = config.settings['labels'] || {}
        @decimal_separator = config.custom_decimal_separator
      end

      def process_transactions(transactions)
        CSV.open(@target_file, 'w', col_sep: @config.column_separator) do |csv|
          transactions.each do |tx|
            csv << transaction_to_csv(tx)
          end
        end
      end

      private

      def transaction_to_csv(tx)
        raise "Currently unsupported" if tx.swap?

        amount = tx.crypto_amount
        total = tx.fiat_amount
        asset = tx.crypto_currency.code
        currency = tx.fiat_currency.code
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

      def format_float(value, prec)
        s = sprintf("%.#{prec}f", value)
        s.gsub!(/\./, @decimal_separator) if @decimal_separator
        s
      end
    end
  end
end
