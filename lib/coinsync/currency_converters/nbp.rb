require 'json'
require 'net/http'
require 'tzinfo'

require_relative 'base'
require_relative '../request'

module CoinSync
  module CurrencyConverters
    class NBP < Base
      register_converter :nbp

      BASE_URL = "https://api.nbp.pl/api"
      POLISH_TIMEZONE = TZInfo::Timezone.get('Europe/Warsaw')

      class Exception < StandardError; end
      class NoDataException < Exception; end

      def get_conversion_rate(from:, to:, time:)
        (from.is_a?(FiatCurrency)) or raise "#{self.class}: 'from' should be a FiatCurrency"
        (to.is_a?(FiatCurrency)) or raise "#{self.class}: 'to' should be a FiatCurrency"
        (time.is_a?(Time)) or raise "#{self.class}: 'time' should be a Time"

        raise "Only conversions to PLN are supported" if to.code != 'PLN'

        date = POLISH_TIMEZONE.utc_to_local(time.utc).to_date

        if rate = @cache[from, to, date]
          return rate
        end

        json = Request.get_json("#{BASE_URL}/exchangerates/rates/a/#{from.code}/#{date - 8}/#{date - 1}/?format=json")

        rate = json['rates'] && json['rates'].last && json['rates'].last['mid']
        raise NoDataException.new("No exchange rate found for #{from.code.upcase}") if rate.nil?

        @cache[from, to, date] = rate

        return rate
      end
    end
  end
end
