require 'ostruct'
require 'tzinfo'
require 'yaml'

require_relative 'currencies'
require_relative 'currency_converters/all'
require_relative 'price_loaders/all'
require_relative 'source'

module CoinSync
  class Config
    attr_reader :source_definitions, :settings

    DEFAULT_CONFIG = 'config.yml'

    def self.load_from_file(filename = nil)
      yaml = YAML.load(File.read(filename || DEFAULT_CONFIG))
      self.new(yaml, filename)
    end

    def initialize(yaml, config_path = nil)
      @source_definitions = yaml['sources'] or raise 'Config: No sources listed'
      @settings = yaml['settings'] || {}
      @labels = @settings['labels'] || {}

      if includes = yaml['include']
        includes.each do |file|
          directory = config_path ? [config_path, '..'] : ['.']
          require(File.expand_path(File.join(*directory, file)))
        end
      end
    end

    def sources
      @sources ||= Hash[@source_definitions.keys.map { |key| [key, Source.new(self, key)] }]
    end

    def filtered_sources(selected, except = nil)
      included = if selected.nil? || selected.empty?
        sources.values
      else
        selected = [selected] unless selected.is_a?(Array)

        selected.map do |key|
          sources[key] or raise "Source not found in the config file: '#{key}'"
        end
      end

      if except
        except = [except] unless except.is_a?(Array)
        included -= except.map { |key| sources[key] }
      end

      Hash[included.map { |source| [source.key, source] }]
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

    def currency_conversion
      settings['convert_currency'] && CurrencyConversionOptions.new(settings['convert_currency'])
    end

    def value_estimation
      settings['estimate_value'] && ValueEstimationOptions.new(settings['estimate_value'])
    end

    def time_format
      settings['time_format']
    end

    def timezone
      settings['timezone'] && TZInfo::Timezone.get(settings['timezone'])
    end

    def translate(label)
      @labels[label] || label
    end

    class CurrencyConversionOptions < OpenStruct
      DEFAULT_CURRENCY_CONVERTER = :exchangeratesapi

      def initialize(options)
        super

        if options['using']
          self.currency_converter_name = options['using'].to_sym
        else
          self.currency_converter_name = DEFAULT_CURRENCY_CONVERTER
        end

        if options['to']
          self.currency = FiatCurrency.new(options['to'].upcase)
        else
          raise "'convert_currency' requires a 'to' field with a currency code"
        end
      end

      def currency_converter
        currency_converter_class = CurrencyConverters.registered[currency_converter_name]

        if currency_converter_class
          currency_converter_class.new(self)
        else
          raise "Unknown currency converter: #{currency_converter_name}"
        end
      end
    end

    class ValueEstimationOptions < OpenStruct
      def initialize(options)
        super

        if options['using']
          self.price_loader_name = options['using'].to_sym
        else
          raise "'value_estimation' requires a 'using' field with a name of a price loader"
        end
      end

      def price_loader
        price_loader_class = PriceLoaders.registered[price_loader_name]

        if price_loader_class
          price_loader_class.new(self)
        else
          raise "Unknown price loader: #{price_loader_name}"
        end
      end
    end
  end
end 
