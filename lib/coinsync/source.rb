require_relative 'importers/all'

module CoinSync
  class Source
    attr_reader :key, :params, :filename

    def initialize(config, key)
      @config = config
      @key = key

      definition = config.source_definitions[key]

      if definition.is_a?(Hash)
        @params = definition
        @filename = definition['file']
        type = (definition['type'] || key).to_sym
      elsif definition.is_a?(String)
        @params = {}
        @filename = definition
        type = key.to_sym
      elsif !config.source_definitions.has_key?(key)
        raise "No such key in source list: '#{key}'"
      else
        raise "Unexpected source definition for '#{key}': #{definition}"
      end

      @importer_class = Importers.registered[type]

      if @importer_class.nil?
        if @params['type']
          raise "Unknown source type for '#{key}': #{params['type']}"
        else
          raise "Unknown source type for '#{key}': please include a 'type' parameter " +
            "or use a name of an existing importer"
        end
      end
    end

    def importer
      @importer ||= @importer_class.new(@config, @params)
    end
  end
end 
