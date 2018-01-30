Dir[File.join(File.dirname(__FILE__), 'parsers', '*.rb')].each { |f| load(f) }

module CoinSync
  class Builder
    def initialize(config)
      @parsers = {}
      @config = config

      register_parser :kraken, Parsers::Kraken
      register_parser :bitbay20, Parsers::BitBay20
    end

    def register_parser(name, klass)
      @parsers[name] = klass.new
    end

    def build(filename)
      transactions = []

      @config.each do |key, params|
        parser = @parsers[params['format'].to_sym] or raise "Unknown format for '#{key}': #{params['format']}"

        File.open(params['file'], 'r') do |file|
          transactions.concat(parser.process(file))
        end
      end

      CSV.open(filename, 'w', col_sep: ';') do |output|
        transactions.sort_by { |tx| tx.time }.each_with_index do |tx, i|
          tx.number = i + 1
          output << tx.to_line
        end
      end
    end
  end
end
