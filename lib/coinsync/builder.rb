Dir[File.join(File.dirname(__FILE__), 'importers', '*.rb')].each { |f| load(f) }

module CoinSync
  class Builder
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

    def build(filename, &block)
      transactions = []

      @config.sources.each do |key, params|
        importer = @importers[params['type'].to_sym] or raise "Unknown source type for '#{key}': #{params['type']}"

        File.open(params['file'], 'r') do |file|
          transactions.concat(importer.read_transaction_list(file))
        end
      end

      if block.nil?
        formatter = Importers::Default.new(@config)
        block = proc { |tx, csv| csv << formatter.save_to_csv(tx) }
      end

      CSV.open(filename, 'w', col_sep: @config.column_separator) do |csv|
        transactions.sort_by { |tx| tx.time }.each_with_index do |tx, i|
          tx.number = i + 1
          block.call(tx, csv)
        end
      end
    end
  end
end
