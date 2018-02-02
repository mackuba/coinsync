require 'time'

require_relative '../currencies'
require_relative '../transaction'

Dir[File.join(File.dirname(__FILE__), '..', 'currency_converters', '*.rb')].each { |f| load(f) }

module CoinSync
  module Outputs
    class CurrencyConverter
      def initialize(config)
        @config = config
        @converter = CurrencyConverters::Fixer.new
        @target_currency = config.convert_to_currency
      end

      def process_transactions(transactions)
        transactions.each do |tx|
          print '.'

          if tx.bought_currency.fiat? && tx.bought_currency != @target_currency
            tx.converted = Transaction::ConvertedAmounts.new
            tx.converted.bought_currency = @target_currency
            tx.converted.bought_amount = @converter.convert(
              tx.bought_amount,
              from: tx.bought_currency,
              to: @target_currency,
              date: tx.time.to_date
            )
            tx.converted.sold_currency = tx.sold_currency
            tx.converted.sold_amount = tx.sold_amount
          elsif tx.sold_currency.fiat? && tx.sold_currency != @target_currency
            tx.converted = Transaction::ConvertedAmounts.new
            tx.converted.sold_currency = @target_currency
            tx.converted.sold_amount = @converter.convert(
              tx.sold_amount,
              from: tx.sold_currency,
              to: @target_currency,
              date: tx.time.to_date
            )
            tx.converted.bought_currency = tx.bought_currency
            tx.converted.bought_amount = tx.bought_amount
          end
        end

        puts
      end
    end
  end
end
