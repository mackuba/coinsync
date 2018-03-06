require 'yaml'

require_relative 'source'

module CoinSync
  class Config
    attr_reader :source_definitions, :settings

    DEFAULT_CONFIG = 'config.yml'

    def self.load_from_file(filename = nil)
      yaml = YAML.load(File.read(filename || DEFAULT_CONFIG))
      self.new(yaml)
    end

    def initialize(yaml)
      @source_definitions = yaml['sources'] or raise 'Config: No sources listed'
      @settings = yaml['settings'] || {}
      @labels = @settings['labels'] || {}

      if includes = yaml['include']
        includes.each do |file|
          require(File.expand_path(File.join('.', file)))
        end
      end

      set_timezone(timezone) if timezone
    end

    def sources
      @sources ||= Hash[@source_definitions.keys.map { |key| [key, Source.new(self, key)] }]
    end

    def set_timezone(timezone)
      ENV['TZ'] = timezone
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
      settings['convert_with']&.to_sym || :fixer
    end

    def time_format
      settings['time_format']
    end

    def timezone
      settings['timezone']
    end

    def translate(label)
      @labels[label] || label
    end
  end
end 
