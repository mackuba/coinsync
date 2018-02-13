require 'bigdecimal'

module CoinSync
  class Formatter
    def initialize(config)
      @config = config
      @decimal_separator = config.custom_decimal_separator
    end

    def format_decimal(value, precision: nil)
      v = precision ? value.round(precision) : value
      s = v.to_s('F').gsub(/\.0$/, '')
      s = s.gsub(/\./, @decimal_separator) if @decimal_separator
      s
    end

    def format_float(value, precision:)
      s = sprintf("%.#{precision}f", value)
      s = s.gsub(/\./, @decimal_separator) if @decimal_separator
      s
    end

    def format_fiat(amount)
      format_float(amount, precision: 2)
    end

    def format_fiat_price(amount)
      format_float(amount, precision: (amount < 10 ? 4 : 2))
    end

    def format_crypto(amount)
      format_decimal(amount, precision: 8)
    end

    def format_time(time)
      time.strftime(@config.time_format || '%Y-%m-%d %H:%M:%S')
    end

    def parse_decimal(string)
      string = string.gsub(@decimal_separator, '.') if @decimal_separator
      BigDecimal.new(string)
    end
  end
end
