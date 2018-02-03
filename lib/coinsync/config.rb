require 'yaml'

module CoinSync
  class Config
    attr_reader :sources, :settings

    def initialize(yaml)
      @sources = yaml['sources'] or raise 'Config: No sources listed'
      @settings = yaml['settings'] || {}
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

    def self.load_from_file(filename)
      yaml = YAML.load(File.read(filename))
      self.new(yaml)
    end
  end
end 
