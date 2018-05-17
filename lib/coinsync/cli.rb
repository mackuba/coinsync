require 'optparse'

require_relative 'balance_task'
require_relative 'build_task'
require_relative 'config'
require_relative 'import_task'
require_relative 'run_command_task'
require_relative 'source_filter'

module CoinSync
  class CLI
    def initialize
      @option_parser = OptionParser.new
    end

    def execute(args)
      @option_parser.on('-cCONFIG', '--config CONFIG') { |c| @config_file = c }
      @option_parser.parse!

      command = args.shift

      if command.nil?
        print_help
      elsif [:balance, :import, :build, :run].include?(command.to_sym)
        @config = load_config
        self.send(command, args)
      else
        raise "Unknown command #{command}"
      end
    end

    def print_help
      puts "Usage:"
      puts "  coinsync balance [source1 source2 ^excluded_source...]"
      puts "    - imports and prints wallet balances from all or selected sources"
      puts
      puts "  coinsync import [source1 source2 ^excluded_source...]"
      puts "    - imports transaction histories from all or selected sources to files listed in the config"
      puts
      puts "  coinsync build list"
      puts "    - merges all transaction histories into a single list and saves it to build/list.csv"
      puts
      puts "  coinsync build fifo"
      puts "    - merges all transaction histories into a single list, calculates transaction"
      puts "      profits using FIFO and saves the result to build/fifo.csv"
      puts
      puts "  coinsync build summary"
      puts "    - merges all transaction histories into a single list and calculates how many"
      puts "      units of each token you should have in total now"
      puts
      puts "  coinsync run <source> <command> [args]"
      puts "    - executes a custom action from one of the configured importers (see docs for more info)"
      puts
      puts "  * add -c file.yml / --config file.yml to use a custom config path instead of config.yml"
      puts
    end

    def balance(args)
      selected, except = parse_sources(args)
      task = BalanceTask.new(@config)
      task.run(selected, except)
    end

    def import(args)
      selected, except = parse_sources(args)
      task = ImportTask.new(@config)
      task.run(selected, except)
    end

    def build(args)
      output_name = args.shift
      task = BuildTask.new(@config)
      task.run(output_name, args)
    end

    def run(args)
      source = args.shift or (puts "Usage: coinsync run <source> <command> [args]"; exit 1)
      command = args.shift or (puts "Usage: coinsync run <source> <command> [args]"; exit 1)

      task = RunCommandTask.new(@config)
      task.run(source, command, args)
    end

    def load_config
      Config.load_from_file(@config_file)
    end

    def parse_sources(args)
      SourceFilter.new.parse_command_line_args(args)
    end
  end
end
