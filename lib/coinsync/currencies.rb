module CoinSync
  Currency = Struct.new(:code)

  class FiatCurrency < Currency
    def fiat?
      true
    end

    def crypto?
      false
    end
  end

  class CryptoCurrency < Currency
    def fiat?
      false
    end

    def crypto?
      true
    end
  end
end
