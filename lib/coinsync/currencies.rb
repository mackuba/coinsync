module CoinSync
  Currency = Struct.new(:code)
  FiatCurrency = Class.new(Currency)
  CryptoCurrency = Class.new(Currency)
end
