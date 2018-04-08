require_relative 'base'
require_relative '../utils'

module CoinSync
  module PriceLoaders
    class Kraken < Base
      def initialize
        super

        Utils.lazy_require(self, 'cointools')

        @cryptowatch ||= CoinTools::Cryptowatch.new
      end

      def currency
        FiatCurrency.new('USD')
      end

      def fetch_price(coin, time)
        result = @cryptowatch.get_price('kraken', "#{coin.code.downcase}usd", time)
        result.price
      end
    end
  end
end
