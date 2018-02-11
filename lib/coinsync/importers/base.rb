module CoinSync
  module Importers
    class Base
      def initialize(config, params = {})
        @config = config
        @params = params
      end
    end
  end
end
