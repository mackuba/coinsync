require 'bigdecimal'

require_relative 'currencies'

module CoinSync
  class Transaction
    TYPE_PURCHASE = :purchase
    TYPE_SALE = :sale
    TYPE_SWAP = :swap

    module Amounts
      attr_reader :bought_currency, :sold_currency, :bought_amount, :sold_amount

      def type
        if bought_currency.crypto?
          if sold_currency.crypto?
            return TYPE_SWAP
          else
            return TYPE_PURCHASE
          end
        else
          return TYPE_SALE
        end
      end

      def purchase?
        type == TYPE_PURCHASE
      end

      def sale?
        type == TYPE_SALE
      end

      def swap?
        type == TYPE_SWAP
      end

      def fiat_amount
        case type
        when TYPE_PURCHASE then sold_amount
        when TYPE_SALE then bought_amount
        else raise "Operation not supported for crypto swap transactions"
        end
      end

      def crypto_amount
        case type
        when TYPE_PURCHASE then bought_amount
        when TYPE_SALE then sold_amount
        else raise "Operation not supported for crypto swap transactions"
        end
      end

      def fiat_currency
        case type
        when TYPE_PURCHASE then sold_currency
        when TYPE_SALE then bought_currency
        else raise "Operation not supported for crypto swap transactions"
        end
      end

      def crypto_currency
        case type
        when TYPE_PURCHASE then bought_currency
        when TYPE_SALE then sold_currency
        else raise "Operation not supported for crypto swap transactions"
        end
      end

      def price
        fiat_amount / crypto_amount
      end
    end

    class ConvertedAmounts
      include Amounts
      attr_writer :bought_currency, :sold_currency, :bought_amount, :sold_amount
      attr_accessor :exchange_rate
    end

    attr_reader :exchange, :time
    attr_accessor :number, :converted

    include Amounts

    def initialize(number: nil, exchange:, bought_currency:, sold_currency:, time:, bought_amount:, sold_amount:)
      @number = number
      @exchange = exchange

      if time.is_a?(Time)
        @time = time.getlocal
      else
        raise "Transaction: '#{time}' is not a valid Time object"
      end

      if bought_amount.is_a?(BigDecimal)
        @bought_amount = bought_amount
      else
        raise "Transaction: '#{bought_amount}' should be a BigDecimal"
      end

      if bought_currency.is_a?(Currency)
        @bought_currency = bought_currency
      else
        raise "Transaction: '#{bought_currency}' is not a valid currency"
      end

      (bought_amount >= 0) or raise "Transaction: bought_amount should not be negative (#{bought_amount})"

      if sold_amount.is_a?(BigDecimal)
        @sold_amount = sold_amount
      else
        raise "Transaction: '#{sold_amount}' should be a BigDecimal"
      end

      if sold_currency.is_a?(Currency) || sold_amount == 0
         @sold_currency = sold_currency
      else
        raise "Transaction: '#{sold_currency}' is not a valid currency"
      end

      (sold_amount >= 0) or raise "Transaction: sold_amount should not be negative (#{sold_amount})"
    end
  end
end
