module CoinSync
  class Currency < Struct.new(:code)
    def <=>(other)
      self.code <=> other.code
    end
  end

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
