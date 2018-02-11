module CoinSync
  module Importers
    def self.registered
      @importers ||= {}
    end

    class Base
      def self.register_as(key)
        if Importers.registered[key]
          raise "Importer has already been registered at '#{key}'"
        else
          Importers.registered[key] = self
        end
      end

      def initialize(config, params = {})
        @config = config
        @params = params
      end
    end
  end
end
