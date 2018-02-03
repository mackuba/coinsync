module CoinSync
  class NumberFormatter
    def initialize(config)
      @config = config
      @decimal_separator = config.custom_decimal_separator
    end

    def format_float(value, precision:, trailing_zeros: true)
      s = sprintf("%.#{precision}f", value)
      s = s.gsub(/0+$/, '').gsub(/\.$/, '') unless trailing_zeros
      s = s.gsub(/\./, @decimal_separator) if @decimal_separator
      s
    end

    def format_fiat(amount)
      format_float(amount, precision: 2, trailing_zeros: true)
    end

    def format_crypto(amount)
      format_float(amount, precision: 8, trailing_zeros: false)
    end
  end
end
