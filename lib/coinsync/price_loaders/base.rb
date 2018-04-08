require 'bigdecimal'

require_relative 'cache'
require_relative '../currencies'

module CoinSync
  module PriceLoaders
    class Base
      def initialize
        @cache = Cache.new(self.class.name.downcase.split('::').last)
        @currency = currency
      end

      def get_price(coin, time)
        (coin.is_a?(CryptoCurrency)) or raise "#{self.class}: 'coin' should be a CryptoCurrency"
        (time.is_a?(Time)) or raise "#{self.class}: 'time' should be a Time"

        price = @cache[coin, time]

        if price.nil?
          price = fetch_price(coin, time)
          @cache[coin, time] = price
        end

        [convert_price(price), @currency]
      end

      def convert_price(price)
        case price
        when BigDecimal then price
        when String, Integer then BigDecimal.new(price)
        when Float then BigDecimal.new(price, 0)
        else raise "Unexpected price value: #{price.inspect}"
        end
      end

      def finalize
        @cache.save
      end
    end
  end
end
