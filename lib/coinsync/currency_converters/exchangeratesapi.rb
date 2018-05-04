require_relative 'base'
require_relative '../request'

module CoinSync
  module CurrencyConverters
    class ExchangeRatesAPI < Base
      register_converter :exchangeratesapi

      BASE_URL = "https://exchangeratesapi.io/api"
      ECB_TIMEZONE = TZInfo::Timezone.get('Europe/Berlin')

      class Exception < StandardError; end
      class NoDataException < Exception; end

      def get_conversion_rate(from:, to:, time:)
        (from.is_a?(FiatCurrency)) or raise "#{self.class}: 'from' should be a FiatCurrency"
        (to.is_a?(FiatCurrency)) or raise "#{self.class}: 'to' should be a FiatCurrency"
        (time.is_a?(Time)) or raise "#{self.class}: 'time' should be a Time"

        date = ECB_TIMEZONE.utc_to_local(time.utc).to_date

        if rate = @cache[from, to, date]
          return rate
        end

        json = Request.get_json("#{BASE_URL}/#{date}?base=#{from.code}")

        rate = json['rates'][to.code.upcase]
        raise NoDataException.new("No exchange rate found for #{to.code.upcase}") if rate.nil?

        @cache[from, to, date] = rate

        return rate
      end
    end
  end
end
