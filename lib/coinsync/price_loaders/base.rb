require 'bigdecimal'

require_relative 'cache'
require_relative '../currencies'

module CoinSync
  module PriceLoaders
    def self.registered
      @price_loaders ||= {}
    end

    class Base
      def self.register_price_loader(key)
        if PriceLoaders.registered[key.to_sym]
          raise "Price loader has already been registered at '#{key}'"
        else
          PriceLoaders.registered[key.to_sym] = self
        end
      end

      def initialize(options)
        @options = options
        @currency = currency
        @cache = Cache.new(cache_name)
      end

      def cache_name
        self.class.name.downcase.split('::').last
      end

      def get_price(coin, time)
        (coin.is_a?(CryptoCurrency)) or raise "#{self.class}: 'coin' should be a CryptoCurrency"
        (time.is_a?(Time)) or raise "#{self.class}: 'time' should be a Time"

        data = @cache[coin, time]

        if data.nil?
          data = fetch_price(coin, time)
          @cache[coin, time] = data
        end

        price = data.is_a?(Array) ? data.first : data

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
