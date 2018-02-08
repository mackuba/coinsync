require_relative 'currencies'

module CoinSync
  class CryptoClassifier
    MAX_INDEX = 1_000_000

    def initialize(config)
      @config = config
      @base_currencies = config.base_cryptocurrencies.map { |c| CryptoCurrency.new(c) }
    end

    def is_purchase?(transaction)
      bought_index = @base_currencies.index(transaction.bought_currency) || MAX_INDEX
      sold_index = @base_currencies.index(transaction.sold_currency) || MAX_INDEX

      if bought_index < sold_index
        false
      elsif bought_index > sold_index
        true
      else
        raise "Couldn't determine which cryptocurrency is the base one: #{transaction.bought_currency.code} vs " +
          "#{transaction.sold_currency.code}. Use the `base_cryptocurrencies` setting to explicitly choose " +
          "base cryptocurrencies."
      end
    end
  end
end
