require 'csv'

require_relative 'base'
require_relative 'list'
require_relative '../currencies'
require_relative '../currency_conversion_task'
require_relative '../transaction'

module CoinSync
  module Outputs
    class SplitList < List
      register_output 'split-list'

      def requires_currency_conversion?
        false
      end

      def initialize(config, target_file)
        super

        if @config.value_estimation
          @price_loader = @config.value_estimation.price_loader
        end
      end

      def process_transactions(transactions, *args)
        split_list = split_all_transactions(transactions)
        super(split_list, *args)
      end

      def split_all_transactions(transactions)
        split_list = []

        transactions.each do |tx|
          if tx.purchase? || tx.sale?
            split_list << tx
          else
            sale, purchase = split_transaction(tx)
            split_list << sale
            split_list << purchase
          end
        end

        @price_loader&.finalize

        if options = @config.currency_conversion
          converter = CurrencyConversionTask.new(options)
          converter.process_transactions(split_list)
        end

        split_list
      end

      def split_transaction(tx)
        if @classifier.is_purchase?(tx)
          base = tx.sold_currency
          base_price, fiat_currency = get_coin_price(base, tx.time)
          total_value = tx.sold_amount * base_price
        else
          base = tx.bought_currency
          base_price, fiat_currency = get_coin_price(base, tx.time)
          total_value = tx.bought_amount * base_price
        end

        sale = Transaction.new(
          number: "#{tx.number}.A",
          exchange: tx.exchange,
          time: tx.time,
          sold_currency: tx.sold_currency,
          sold_amount: tx.sold_amount,
          bought_currency: fiat_currency,
          bought_amount: total_value
        )

        purchase = Transaction.new(
          number: "#{tx.number}.B",
          exchange: tx.exchange,
          time: tx.time,
          bought_currency: tx.bought_currency,
          bought_amount: tx.bought_amount,
          sold_currency: fiat_currency,
          sold_amount: total_value
        )

        [sale, purchase]
      end

      def fiat_transaction_to_csv(tx)
        tx_type = @config.translate(tx.type.to_s.capitalize)

        is_split = tx.number.to_s.include?('.')
        is_incomplete = is_split && tx.bought_amount * tx.sold_amount == 0

        if is_split
          tx_type = @config.translate(Transaction::TYPE_SWAP.to_s.capitalize) + '/' + tx_type
        end

        csv = [
          tx.number || 0,
          tx.exchange,
          tx_type,
          @formatter.format_time(tx.time),
          @formatter.format_crypto(tx.crypto_amount),
          tx.crypto_currency.code
        ]

        if is_incomplete
          csv += [nil, nil, nil]
        else
          csv += [
            @formatter.format_fiat(tx.fiat_amount),
            @formatter.format_fiat_price(tx.price),
            tx.fiat_currency.code || '–'
          ]
        end

        if @config.currency_conversion
          if is_incomplete
            csv += [nil, nil, nil]
          elsif tx.converted
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
        # sanity check - this should not happen
        raise "SplitList: unexpected unprocessed swap transaction"
      end

      def get_coin_price(coin, time)
        if @price_loader
          print "$"

          begin
            @price_loader.get_price(coin, time)
          rescue Exception => e
            @price_loader.finalize
            raise
          end
        else
          [BigDecimal.new(0), FiatCurrency.new(nil)]
        end
      end
    end
  end
end
