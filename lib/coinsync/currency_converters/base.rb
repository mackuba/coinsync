require 'bigdecimal'

require_relative 'cache'
require_relative '../currencies'

module CoinSync
  module CurrencyConverters
    def self.registered
      @converters ||= {}
    end

    class Base
      def self.register_converter(key)
        if CurrencyConverters.registered[key]
          raise "Currency converter has already been registered at '#{key}'"
        else
          CurrencyConverters.registered[key] = self
        end
      end

      def initialize(options)
        @options = options
        @cache = Cache.new(self.class.name.downcase.split('::').last)
      end

      def convert(amount, from:, to:, date:)
        (amount > 0) or raise "#{self.class}: amount should be positive"
        (amount.is_a?(BigDecimal)) or raise "#{self.class}: 'amount' should be a BigDecimal"
        (from.is_a?(FiatCurrency)) or raise "#{self.class}: 'from' should be a FiatCurrency"
        (to.is_a?(FiatCurrency)) or raise "#{self.class}: 'to' should be a FiatCurrency"
        (date.is_a?(Date)) or raise "#{self.class}: 'date' should be a Date"

        if rate = @cache[from, to, date]
          return rate * amount
        else
          rate = fetch_conversion_rate(from: from, to: to, date: date)
          @cache[from, to, date] = rate
          return rate * amount
        end
      end

      def finalize
        @cache.save
      end
    end
  end
end
