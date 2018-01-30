Dir[File.join(File.dirname(__FILE__), 'parsers', '*.rb')].each { |f| load(f) }

module CoinSync
  class Builder
    def initialize(config)
      @parsers = {}
      @config = config
      @inputs = @config['inputs']
      @settings = @config['settings'] || {}

      register_parser :bitbay20, Parsers::BitBay20
      register_parser :bitcurex, Parsers::Bitcurex
      register_parser :circle, Parsers::Circle
      register_parser :kraken, Parsers::Kraken
    end

    def register_parser(name, klass)
      @parsers[name] = klass.new
    end

    def build(filename, &block)
      transactions = []

      @inputs.each do |key, params|
        parser = @parsers[params['format'].to_sym] or raise "Unknown format for '#{key}': #{params['format']}"

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
