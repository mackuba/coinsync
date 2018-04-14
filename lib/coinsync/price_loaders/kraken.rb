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
        result = @cryptowatch.get_price_fast('kraken', coin.code.downcase + currency.code.downcase, time)
        [result.price, result.time.to_i]
      end
    end
  end
end
