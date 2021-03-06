require 'csv'

require_relative 'base'

module CoinSync
  module Outputs
    class List < Base
      register_output :list

      def requires_currency_conversion?
        true
      end

      def process_transactions(transactions, *args)
        CSV.open(@target_file, 'w', col_sep: @config.column_separator) do |csv|
          csv << headers

          transactions.each do |tx|
            process_transaction(tx, csv)
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

        if options = @config.currency_conversion
          line += [
            @config.translate('Total value ($CURRENCY)').gsub('$CURRENCY', options.currency.code),
            @config.translate('Price ($CURRENCY)').gsub('$CURRENCY', options.currency.code),
            @config.translate('Exchange rate')
          ]
        end

        line
      end

      def process_transaction(tx, csv)
        csv << transaction_to_csv(tx)
      end

      def transaction_to_csv(tx)
        if tx.purchase? || tx.sale?
          fiat_transaction_to_csv(tx)
        else
          swap_transaction_to_csv(tx)
        end
      end

      def fiat_transaction_to_csv(tx)
        csv = [
          tx.number || 0,
          tx.exchange,
          @config.translate(tx.type.to_s.capitalize),
          @formatter.format_time(tx.time),
          @formatter.format_crypto(tx.crypto_amount),
          tx.crypto_currency.code,
          @formatter.format_fiat(tx.fiat_amount),
          @formatter.format_fiat_price(tx.price),
          tx.fiat_currency.code || '–'
        ]

        if @config.currency_conversion
          if tx.converted
            csv += [
              @formatter.format_fiat(tx.converted.fiat_amount),
              @formatter.format_fiat_price(tx.converted.price),
              tx.converted.exchange_rate && @formatter.format_float(tx.converted.exchange_rate, precision: 4)
            ]
          else
            csv += [
              @formatter.format_fiat(tx.fiat_amount),
              @formatter.format_fiat_price(tx.price),
              nil
            ]
          end
        end

        csv
      end

      def swap_transaction_to_csv(tx)
        if @classifier.is_purchase?(tx)
          tx_type = Transaction::TYPE_PURCHASE
          asset = tx.bought_currency
          asset_amount = tx.bought_amount
          currency = tx.sold_currency
          currency_amount = tx.sold_amount
        else
          tx_type = Transaction::TYPE_SALE
          asset = tx.sold_currency
          asset_amount = tx.sold_amount
          currency = tx.bought_currency
          currency_amount = tx.bought_amount
        end

        csv = [
          tx.number || 0,
          tx.exchange,
          @config.translate(tx_type.to_s.capitalize),
          @formatter.format_time(tx.time),
          @formatter.format_crypto(asset_amount),
          asset.code,
          @formatter.format_crypto(currency_amount),
          @formatter.format_crypto(currency_amount / asset_amount),
          currency.code
        ]

        if @config.currency_conversion
          csv += [nil, nil, nil]
        end

        csv
      end
    end
  end
end
