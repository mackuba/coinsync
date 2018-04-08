require 'csv'

require_relative 'base'
require_relative '../currencies'
require_relative '../currency_converter'
require_relative '../price_loaders/all'
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

        @kraken = PriceLoaders::Kraken.new
      end

      def process_transactions(transactions, *args)
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

        @kraken.finalize

        if @config.convert_to_currency
          converter = CurrencyConverter.new(@config)
          converter.process_transactions(split_list)
        end

        super(split_list, *args)
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

        if tx.number.to_s.include?('.')
          tx_type = @config.translate(Transaction::TYPE_SWAP.to_s.capitalize) + '/' + tx_type
        end

        csv = [
          tx.number || 0,
          tx.exchange,
          tx_type,
          @formatter.format_time(tx.time),
          @formatter.format_crypto(tx.crypto_amount),
          tx.crypto_currency.code,
          @formatter.format_fiat(tx.fiat_amount),
          @formatter.format_fiat_price(tx.price),
          tx.fiat_currency.code || '–'
        ]

        if @config.convert_to_currency
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

      def get_coin_price(coin, time)
        print "$"

        begin
          @kraken.get_price(coin, time)
        rescue Exception => e
          @kraken.finalize
          raise
        end
      end
    end
  end
end
