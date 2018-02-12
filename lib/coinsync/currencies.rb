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
    MAPPING = {
      'XRB' => 'NANO'
    }

    def initialize(code)
      super(MAPPING[code] || code)
    end

    def fiat?
      false
    end

    def crypto?
      true
    end
  end
end
