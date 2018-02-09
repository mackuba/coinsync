Dir[File.join(File.dirname(__FILE__), 'importers', '*.rb')].each { |f| load(f) }

module CoinSync
  class Builder
    attr_reader :transactions

    def initialize(config)
      @config = config

      @importers = {
        default: Importers::Default.new(config),
        bitbay20: Importers::BitBay20.new,
        bitcurex: Importers::Bitcurex.new,
        bittrex: Importers::Bittrex.new,
        changelly: Importers::Changelly.new,
        circle: Importers::Circle.new,
        kraken: Importers::Kraken.new
      }
    end

    def build_transaction_list
      transactions = []

      @config.sources.each do |key, params|
        type = (params.is_a?(Hash) && params['type'] || key).to_sym
        importer = @importers[type]

        if importer.nil?
          if params.is_a?(Hash) && params['type']
            raise "Unknown source type for '#{key}': #{params['type']}"
          else
            raise "Unknown source type for '#{key}': please include a 'type' parameter"
          end
        end

        filename = params.is_a?(Hash) ? params['file'] : params

        File.open(filename, 'r') do |file|
          transactions.concat(importer.read_transaction_list(file))
        end
      end

      transactions.each_with_index { |tx, i| tx.number = i + 1 }

      @transactions = transactions.sort_by { |tx| [tx.time, tx.number] }
      @transactions.each_with_index { |tx, i| tx.number = i + 1 }
    end
  end
end
