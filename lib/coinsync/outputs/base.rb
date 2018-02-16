module CoinSync
  module Outputs
    def self.registered
      @outputs ||= {}
    end

    class Base
      def self.register_output(key)
        if Outputs.registered[key]
          raise "Output has already been registered at '#{key}'"
        else
          Outputs.registered[key] = self
        end
      end

      def initialize(config, target_file)
        @config = config
        @target_file = target_file
      end
    end
  end
end
