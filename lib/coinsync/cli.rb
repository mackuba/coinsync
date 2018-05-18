require 'cri'
require_relative 'cri_hax'

require_relative 'balance_task'
require_relative 'build_task'
require_relative 'config'
require_relative 'import_task'
require_relative 'source_filter'
require_relative 'version'

module CoinSync
  module CLI
    class << self
      attr_accessor :config

      def parse_sources(args)
        SourceFilter.new.parse_command_line_args(args)
      end

      def generate_importer_commands
        run = App.command_named('run')

        config.sources.values.each do |source|
          importer = source.importer

          if !importer.registered_commands.empty?
            wrapper = importer.wrapper_command(source.key)
            run.add_command(wrapper)

            importer.registered_commands.each do |command_name|
              wrapper.add_command(importer.command(command_name))
            end
          end
        end
      end
    end

    Preflight = Cri::Command.define do
      required :c, :config, 'path to a custom config file (default is ./config.yml)'

      flag :v, :version, 'print version number' do |value, cmd|
        puts CoinSync::VERSION
        exit 0
      end

      run do |opts, args, cmd|
        CLI.config = Config.load_from_file(opts[:config])
        CLI.generate_importer_commands
      end
    end

    App = Cri::Command.define do
      name 'coinsync'
      usage 'coinsync [options...] <command> [args...] [options...]'
      summary 'A tool for importing and processing data from cryptocurrency exchanges'
      description "CoinSync is a command-line tool for crypto traders written in Ruby that helps you " +
        "import data like your transaction histories from multiple exchanges, convert it into a single " +
        "unified format and process it in various ways."

      required :c, :config, 'path to a config file (default: config.yml)'

      flag :h, :help, 'show help for this command' do |value, cmd|
        puts cmd.help
        exit 0
      end
    end

    App.define_command('balance') do
      summary 'Import and print wallet balances from all or selected sources'
      usage 'balance [source1 source2 ^excluded_source...]'
      description "You can pass one or more source names as arguments to import balance only from these " +
        "sources. Add a caret character (^) before a source name to import all sources except this one. " +
        "If no arguments are added, all defined sources will be checked."

      run do |opts, args, cmd|
        selected, except = CLI.parse_sources(args)

        task = BalanceTask.new(CLI.config)
        task.run(selected, except)
      end
    end

    App.define_command('import') do
      summary 'Import transaction histories from all or selected sources'
      usage 'import [source1 source2 ^excluded_source...]'
      description "This command imports transaction histories from all available sources defined in the " +
        "config and saves them in CSV or JSON files in the `data` directory.\n\n" +
        "You can pass one or more source names as arguments to import transactions only from these " +
        "sources. Add a caret character (^) before a source name to import all sources except this one. " +
        "If no arguments are added, all defined sources will be imported."

      run do |opts, args, cmd|
        selected, except = CLI.parse_sources(args)

        task = ImportTask.new(CLI.config)
        task.run(selected, except)
      end
    end

    App.define_command('build') do
      summary 'Merge all transaction histories and save or process them as a single list'
      usage 'build <output_type>'
      description "This command reads all imported transaction histories from the files configured in " +
        "the config, merges them into one unified transaction history, and then performs a selected " +
        "task on the combined list. Depending on the task this means either saving the processed list " +
        "to a new file in a specific format, or calculating some kind of summary from all the data.\n\n" +
        "Available output types:\n\n" +
        "list - A simple list, one line per transaction in a unified format (build/list.csv)\n\n" +
        "split-list - A list with all crypto-to-crypto transactions split into a separate buy " +
        "and sell (build/split-list.csv)\n\n" +
        "raw - Like list, but in a format potentially more suitable for further processing with " +
        "other tools (build/raw.csv)\n\n" +
        "summary - Calculates the final balance of each currency you should have at the moment " +
        "according to the transaction history"        

      run do |opts, args, cmd|
        output_name, *rest = args

        task = BuildTask.new(CLI.config)
        task.run(output_name, rest)
      end
    end

    App.define_command('run') do
      summary 'Execute a custom action from one of the configured importers'
      usage 'run <source> <command> [args]'
      description "Some importers may have custom commands implemented that only make sense for a given " +
        "importer. This allows you to run these commands from the command line."
    end
  end
end
