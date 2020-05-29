require 'fileutils'
require 'json'

module CoinSync
  module PriceLoaders
    class Cache
      def initialize(name)
        @name = name
        @filename = "data/prices/#{name}.json"

        if File.exist?(@filename)
          @prices = JSON.parse(File.read(@filename))
        else
          @prices = {}
        end
      end

      def [](coin, time)
        @prices[coin.code] ||= {}
        @prices[coin.code][time.to_i.to_s]
      end

      def []=(coin, time, price)
        @prices[coin.code] ||= {}
        @prices[coin.code][time.to_i.to_s] = price
      end

      def save
        @prices.keys.each do |k|
          @prices[k] = Hash[@prices[k].sort]
        end

        FileUtils.mkdir_p(File.dirname(@filename))
        File.write(@filename, JSON.pretty_generate(@prices))
      end
    end
  end
end
