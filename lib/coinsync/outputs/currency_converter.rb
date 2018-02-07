require 'time'

require_relative '../currencies'
require_relative '../transaction'

Dir[File.join(File.dirname(__FILE__), '..', 'currency_converters', '*.rb')].each { |f| load(f) }

module CoinSync
  module Outputs
    class CurrencyConverter
      def initialize(config)
        @config = config

        @converter = case config.currency_converter || :fixer
        when :fixer then CurrencyConverters::Fixer.new
        when :nbp then CurrencyConverters::NBP.new
        else raise "Unknown currency converter #{config.currency_converter}"
        end

        @target_currency = config.convert_to_currency
      end

      def process_transactions(transactions)
        transactions.each do |tx|
          print '.'

          if tx.bought_currency.fiat? && tx.bought_currency != @target_currency
            tx.converted = Transaction::ConvertedAmounts.new
            tx.converted.bought_currency = @target_currency
            tx.converted.exchange_rate = @converter.convert(
              1.0,
              from: tx.bought_currency,
              to: @target_currency,
              date: tx.time.to_date
            )
            tx.converted.bought_amount = tx.bought_amount * tx.converted.exchange_rate
            tx.converted.sold_currency = tx.sold_currency
            tx.converted.sold_amount = tx.sold_amount
          elsif tx.sold_currency.fiat? && tx.sold_currency != @target_currency
            tx.converted = Transaction::ConvertedAmounts.new
            tx.converted.bought_currency = tx.bought_currency
            tx.converted.bought_amount = tx.bought_amount
            tx.converted.sold_currency = @target_currency

            if tx.sold_currency.code
              tx.converted.exchange_rate = @converter.convert(
                1.0,
                from: tx.sold_currency,
                to: @target_currency,
                date: tx.time.to_date
              )
              tx.converted.sold_amount = tx.sold_amount * tx.converted.exchange_rate
            else
              tx.converted.exchange_rate = nil
              tx.converted.sold_amount = 0.0
            end
          end
        end

        @converter.finalize

        puts
      end
    end
  end
end
