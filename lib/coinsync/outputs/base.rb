require_relative '../crypto_classifier'
require_relative '../formatter'

module CoinSync
  module Outputs
    def self.registered
      @outputs ||= {}
    end

    class Base
      def self.register_output(key)
        if Outputs.registered[key.to_sym]
          raise "Output has already been registered at '#{key}'"
        else
          Outputs.registered[key.to_sym] = self
        end
      end

      def initialize(config, target_file)
        @config = config
        @target_file = target_file

        @formatter = Formatter.new(config)
        @classifier = CryptoClassifier.new(config)
      end

      def requires_currency_conversion?
        false
      end
    end
  end
end
