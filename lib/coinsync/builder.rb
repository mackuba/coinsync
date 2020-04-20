require_relative 'importers/all'

module CoinSync
  class Builder
    attr_reader :transactions

    def initialize(config)
      @config = config
    end

    def build_transaction_list
      list = []

      @config.sources.each do |key, source|
        if source.importer.can_build?
          if source.filename.nil?
            raise "No filename specified for '#{key}', please add a 'file' parameter."
          end

          File.open(source.filename, 'r') do |file|
            transactions = source.importer.read_transaction_list(file)

            list.concat(transactions.select { |tx| source.date_filters.any? { |f| f.range_includes(tx) }})
          end
        end
      end

      list.each_with_index { |tx, i| tx.number = i + 1 }

      @transactions = list.sort_by { |tx| [tx.time, tx.number] }
      @transactions.each_with_index { |tx, i| tx.number = i + 1 }
    end
  end
end
