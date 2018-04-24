require_relative 'base'
require_relative '../utils'

module CoinSync
  module PriceLoaders
    class Cryptowatch < Base
      register_price_loader :cryptowatch

      def initialize(options)
        options.currency = options.currency&.upcase || 'USD'
        options.exchange ||= 'bitfinex'

        super

        Utils.lazy_require(self, 'cointools')

        @cryptowatch ||= CoinTools::Cryptowatch.new
      end

      def cache_name
        "cryptowatch-#{@options.exchange}-#{@options.currency.downcase}"
      end

      def currency
        FiatCurrency.new(@options.currency)
      end

      def fetch_price(coin, time)
        result = @cryptowatch.get_price_fast(@options.exchange, coin.code.downcase + @options.currency.downcase, time)
        [result.price, result.time.to_i]
      end
    end
  end
end
