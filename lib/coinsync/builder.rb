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
        circle: Importers::Circle.new,
        kraken: Importers::Kraken.new
      }
    end

    def build_transaction_list
      transactions = []

      @config.sources.each do |key, params|
        importer = @importers[params['type'].to_sym] or raise "Unknown source type for '#{key}': #{params['type']}"

        File.open(params['file'], 'r') do |file|
          transactions.concat(importer.read_transaction_list(file))
        end
      end

      @transactions = transactions.sort_by { |tx| tx.time }
      @transactions.each_with_index { |tx, i| tx.number = i + 1 }
    end
  end
end
