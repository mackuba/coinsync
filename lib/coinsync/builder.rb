Dir[File.join(File.dirname(__FILE__), 'parsers', '*.rb')].each { |f| load(f) }

module CoinSync
  class Builder
    def initialize(config)
      @config = config
      @sources = @config['sources']
      @settings = @config['settings'] || {}

      @parsers = {
        bitbay20: Parsers::BitBay20.new,
        bitcurex: Parsers::Bitcurex.new,
        circle: Parsers::Circle.new,
        default: Parsers::Default.new(@settings),
        kraken: Parsers::Kraken.new
      }
    end

    def register_parser(name, klass)
      @parsers[name] = klass.new
    end

    def build(filename, &block)
      transactions = []

      @sources.each do |key, params|
        parser = @parsers[params['type'].to_sym] or raise "Unknown source type for '#{key}': #{params['type']}"

        File.open(params['file'], 'r') do |file|
          transactions.concat(parser.process(file))
        end
      end

      if block.nil?
        formatter = Parsers::Default.new(@settings)
        block = proc { |tx, csv| csv << formatter.save_to_csv(tx) }
      end

      CSV.open(filename, 'w', col_sep: @settings['column_separator'] || ',') do |csv|
        transactions.sort_by { |tx| tx.time }.each_with_index do |tx, i|
          tx.number = i + 1
          block.call(tx, csv)
        end
      end
    end
  end
end
