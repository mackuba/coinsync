Dir[File.join(File.dirname(__FILE__), 'importers', '*.rb')].each { |f| load(f) }

module CoinSync
  class Builder
    attr_reader :transactions

    def initialize(config)
      @config = config
    end

    def build_transaction_list
      transactions = []

      @config.sources.each do |importer, key, params, filename|
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
