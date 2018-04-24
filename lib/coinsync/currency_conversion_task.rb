require 'bigdecimal'
require 'time'

require_relative 'transaction'

module CoinSync
  class CurrencyConversionTask
    def initialize(options)
      @options = options
      @target_currency = options.currency
      @converter = options.currency_converter
    end

    def process_transactions(transactions)
      transactions.each do |tx|
        print '.'

        if tx.bought_currency.fiat? && tx.bought_currency != @target_currency
          tx.converted = Transaction::ConvertedAmounts.new
          tx.converted.sold_currency = tx.sold_currency
          tx.converted.sold_amount = tx.sold_amount
          tx.converted.bought_currency = @target_currency

          if tx.bought_currency.code
            tx.converted.exchange_rate = @converter.convert(
              BigDecimal.new(1),
              from: tx.bought_currency,
              to: @target_currency,
              date: tx.time.to_date
            )
            tx.converted.bought_amount = tx.bought_amount * tx.converted.exchange_rate
          else
            tx.converted.exchange_rate = nil
            tx.converted.bought_amount = BigDecimal.new(0)
          end
        elsif tx.sold_currency.fiat? && tx.sold_currency != @target_currency
          tx.converted = Transaction::ConvertedAmounts.new
          tx.converted.bought_currency = tx.bought_currency
          tx.converted.bought_amount = tx.bought_amount
          tx.converted.sold_currency = @target_currency

          if tx.sold_currency.code
            tx.converted.exchange_rate = @converter.convert(
              BigDecimal.new(1),
              from: tx.sold_currency,
              to: @target_currency,
              date: tx.time.to_date
            )
            tx.converted.sold_amount = tx.sold_amount * tx.converted.exchange_rate
          else
            tx.converted.exchange_rate = nil
            tx.converted.sold_amount = BigDecimal.new(0)
          end
        end
      end

      @converter.finalize

      puts
    end
  end
end
