require 'fileutils'
require 'json'

module CoinSync
  module CurrencyConverters
    class Cache
      def initialize(name)
        @name = name
        @filename = "caches/#{name}.json"

        if File.exist?(@filename)
          @rates = JSON.parse(File.read(@filename))
        else
          @rates = {}
        end
      end

      def [](from, to, date)
        @rates["#{from.code}:#{to.code}"] ||= {}
        @rates["#{from.code}:#{to.code}"][date.to_s]
      end

      def []=(from, to, date, amount)
        @rates["#{from.code}:#{to.code}"] ||= {}
        @rates["#{from.code}:#{to.code}"][date.to_s] = amount
      end

      def save
        FileUtils.mkdir_p(File.dirname(@filename))
        File.write(@filename, JSON.generate(@rates))
      end
    end
  end
end
