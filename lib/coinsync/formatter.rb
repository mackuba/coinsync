module CoinSync
  class Formatter
    def initialize(config)
      @config = config
      @decimal_separator = config.custom_decimal_separator
    end

    def format_float(value, precision:, remove_trailing_zeros: false)
      s = sprintf("%.#{precision}f", value)
      s = s.gsub(/0+$/, '').gsub(/\.$/, '') if remove_trailing_zeros
      s = s.gsub(/\./, @decimal_separator) if @decimal_separator
      s
    end

    def format_fiat(amount)
      format_float(amount, precision: 2)
    end

    def format_crypto(amount)
      format_float(amount, precision: 8, remove_trailing_zeros: true)
    end

    def format_time(time)
      time.strftime(@config.time_format || '%Y-%m-%d %H:%M:%S')
    end
  end
end
