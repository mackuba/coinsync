require_relative 'currencies'

module CoinSync
  class Transaction
    TYPE_PURCHASE = :purchase
    TYPE_SALE = :sale
    TYPE_SWAP = :swap

    attr_reader :number, :exchange, :bought_currency, :sold_currency, :time, :bought_amount, :sold_amount
    attr_writer :number

    def initialize(number: nil, exchange:, bought_currency:, sold_currency:, time:, bought_amount:, sold_amount:)
      if number.nil? || number.is_a?(Integer)
        @number = number
      else
        raise "Transaction: '#{number}' is not an integer"
      end

      @exchange = exchange

      if bought_currency.is_a?(Currency)
        @bought_currency = bought_currency
      else
        raise "Transaction: '#{bought_currency}' is not a valid currency"
      end

      if sold_currency.is_a?(Currency)
         @sold_currency = sold_currency
      else
        raise "Transaction: '#{sold_currency}' is not a valid currency"
      end

      if time.is_a?(Time)
        @time = time
      else
        raise "Transaction: '#{time}' is not a valid Time object"
      end

      if bought_amount.is_a?(Numeric)
        @bought_amount = bought_amount
      else
        raise "Transaction: '#{bought_amount}' is not a number"
      end

      if sold_amount.is_a?(Numeric)
        @sold_amount = sold_amount
      else
        raise "Transaction: '#{sold_amount}' is not a number"
      end
    end

    def type
      if bought_currency.is_a?(CryptoCurrency)
        if sold_currency.is_a?(CryptoCurrency)
          return TYPE_SWAP
        else
          return TYPE_PURCHASE
        end
      else
        return TYPE_SALE
      end
    end
  end
end
