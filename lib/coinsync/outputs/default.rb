require 'csv'

require_relative '../number_formatter'

module CoinSync
  module Outputs
    class Default
      def initialize(config, target_file)
        @config = config
        @target_file = target_file
        @formatter = NumberFormatter.new(config)
      end

      def process_transactions(transactions)
        CSV.open(@target_file, 'w', col_sep: @config.column_separator) do |csv|
          csv << headers

          transactions.each do |tx|
            csv << transaction_to_csv(tx)
          end
        end
      end

      def headers
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
        ].map { |l| @config.translate(l) }

        if currency = @config.convert_to_currency
          line += [
            @config.translate('Total value ($CURRENCY)').gsub('$CURRENCY', currency.code),
            @config.translate('Price ($CURRENCY)').gsub('$CURRENCY', currency.code),
            @config.translate('Exchange rate')
          ]
        end

        line
      end

      def transaction_to_csv(tx)
        raise "Currently unsupported" if tx.swap?

        asset = tx.crypto_currency.code
        currency = tx.fiat_currency.code
        tx_type = tx.type.to_s.capitalize

        csv = [
          tx.number || 0,
          tx.exchange,
          @config.translate(tx_type),
          format_time(tx.time),
          @formatter.format_crypto(tx.crypto_amount),
          asset,
          @formatter.format_fiat(tx.fiat_amount),
          @formatter.format_fiat(tx.price),
          currency
        ]

        if @config.convert_to_currency
          if tx.converted
            csv += [
              @formatter.format_fiat(tx.converted.fiat_amount),
              @formatter.format_fiat(tx.converted.price),
              @formatter.format_float(tx.converted.exchange_rate, precision: 4)
            ]
          else
            csv += [
              @formatter.format_fiat(tx.fiat_amount),
              @formatter.format_fiat(tx.price),
              nil
            ]
          end
        end

        csv
      end

      def format_time(time)
        time.strftime(@config.time_format || '%Y-%m-%d %H:%M:%S')
      end
    end
  end
end
