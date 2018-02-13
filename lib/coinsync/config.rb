require 'yaml'

module CoinSync
  class Config
    attr_reader :settings

    def self.load_from_file(filename)
      yaml = YAML.load(File.read(filename))
      self.new(yaml)
    end

    def initialize(yaml)
      @sources = yaml['sources'] or raise 'Config: No sources listed'
      @settings = yaml['settings'] || {}
      @labels = @settings['labels'] || {}

      if includes = yaml['include']
        includes.each do |file|
          require(File.expand_path(File.join('.', file)))
        end
      end
    end

    def sources
      @importers ||= @sources.map do |key, params|
        if params.is_a?(Hash)
          filename = params['file']
          importer_params = params
          type = (params['type'] || key).to_sym
        else
          filename = params
          importer_params = {}
          type = key.to_sym
        end

        importer_class = Importers.registered[type]

        if importer_class.nil?
          if importer_params['type']
            raise "Unknown source type for '#{key}': #{params['type']}"
          else
            raise "Unknown source type for '#{key}': please include a 'type' parameter " +
              "or use a name of an existing importer"
          end
        end

        importer = importer_class.new(self, importer_params)

        [importer, key, importer_params, filename]
      end
    end

    def base_cryptocurrencies
      settings['base_cryptocurrencies'] || ['USDT', 'BTC', 'ETH', 'BNB', 'KCS', 'LTC', 'BCH', 'NEO']
    end

    def column_separator
      settings['column_separator'] || ','
    end

    def decimal_separator
      custom_decimal_separator || '.'
    end

    def custom_decimal_separator
      settings['decimal_separator']
    end

    def convert_to_currency
      settings['convert_to'] ? FiatCurrency.new(settings['convert_to']) : nil
    end

    def currency_converter
      settings['convert_with']&.to_sym
    end

    def time_format
      settings['time_format']
    end

    def translate(label)
      @labels[label] || label
    end
  end
end 
