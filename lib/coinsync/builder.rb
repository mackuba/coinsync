Dir[File.join(File.dirname(__FILE__), 'parsers', '*.rb')].each { |f| load(f) }

module CoinSync
  class Builder
    def initialize(config)
      @parsers = {}
      @config = config

      register_parser :kraken, Parsers::Kraken
    end

    def register_parser(name, klass)
      @parsers[name] = klass.new
    end

    def build(filename)
      @config.each do |entry|
        parser = @parsers[entry['format'].to_sym] or raise "Unknown format: #{entry['format']}"

        File.open(entry['file'], 'r') do |file|
          transactions = parser.process(file)

          CSV.open(filename, 'w', col_sep: ';') do |output|
            transactions.each do |tx|
              output << tx.to_line
            end
          end
        end
      end
    end
  end
end
