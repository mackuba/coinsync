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

      def convert(amount, from:, to:, time:)
        (amount > 0) or raise "#{self.class}: amount should be positive"
        (amount.is_a?(BigDecimal)) or raise "#{self.class}: 'amount' should be a BigDecimal"

        rate = get_conversion_rate(from: from, to: to, time: time)

        rate * amount
      end

      def get_conversion_rate(from:, to:, time:)
        raise "not implemented"
      end

      def finalize
        @cache.save
      end
    end
  end
end
