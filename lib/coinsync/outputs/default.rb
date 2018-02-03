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
          csv << headers(transactions)

          transactions.each do |tx|
            csv << transaction_to_csv(tx)
          end
        end
      end

      private

      def headers(transactions)
        line = [
          'No.',
          'Exchange',
          'Type',
          'Date',
          'Amount',
          'Asset',
          'Total value',
          'Price',
          'Currency'
        ].map { |l| translate(l) }

        if currency = @config.convert_to_currency
          line += [
            translate('Total value ($CURRENCY)').gsub('$CURRENCY', currency.code),
            translate('Price ($CURRENCY)').gsub('$CURRENCY', currency.code)
          ]
        end

        line
      end

      def translate(label)
        @labels[label] || label
      end

      def transaction_to_csv(tx)
        raise "Currently unsupported" if tx.swap?

        amount = tx.crypto_amount
        total = tx.fiat_amount
        asset = tx.crypto_currency.code
        currency = tx.fiat_currency.code
        tx_type = tx.type.to_s.capitalize

        csv = [
          tx.number || 0,
          tx.exchange,
          translate(tx_type),
          tx.time,
          format_float(amount, 8),
          asset,
          format_float(total, 4),
          format_float(total / amount, 4)
        ]

        if tx.converted
          csv += [
            format_float(tx.converted.fiat_amount, 4),
            format_float(tx.converted.fiat_amount / amount, 4)
          ]
        end

        csv
      end

      def format_float(value, prec)
        s = sprintf("%.#{prec}f", value).gsub(/0+$/, '').gsub(/\.$/, '')
        s.gsub!(/\./, @decimal_separator) if @decimal_separator
        s
      end
    end
  end
end
