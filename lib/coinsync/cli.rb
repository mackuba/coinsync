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
    MIN_RUBY_VERSION = 2.4

    class << self
      attr_accessor :config

      def check_ruby_version
        version_f = RUBY_VERSION.split('.')[0..1].join('.').to_f

        if version_f < MIN_RUBY_VERSION
          puts "CoinSync requires Ruby #{MIN_RUBY_VERSION} or later."
          exit 1
        end
      end

      def source_filter(args)
        SourceFilter.from_command_line_args(args)
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
      description <<~DOC
        CoinSync is a command-line tool for crypto traders written in Ruby that helps you
        import data like your transaction histories from multiple exchanges, convert it into a single
        unified format and process it in various ways.
      DOC

      required :c, :config, 'path to a config file (default: config.yml)'

      flag :h, :help, 'show help for this command' do |value, cmd|
        puts cmd.help
        exit 0
      end

      default_subcommand 'help'
    end

    App.define_command('help') do
      summary 'Print help about a given command'
      usage 'help <command> [<subcommand>...]'
      description "Use this to see a message like this about any given command :)"

      run do |opts, args, cmd|
        current = App
        path = args.dup

        while name = path.shift
          current = current.command_named(name)
        end

        puts current.help
      end
    end

    App.define_command('balance') do
      summary 'Import and print wallet balances from all or selected sources'
      usage 'balance [source1 source2 ^excluded_source...]'
      description <<~DOC
        You can pass one or more source names as arguments to import balance only from these
        sources. Add a caret character (^) before a source name to import all sources except this one.
        If no arguments are added, all defined sources will be checked.
      DOC

      run do |opts, args, cmd|
        filter = CLI.source_filter(args)

        task = BalanceTask.new(CLI.config)
        task.run(filter)
      end
    end

    App.define_command('import') do
      summary 'Import transaction histories from all or selected sources'
      usage 'import [source1 source2 ^excluded_source...]'
      description <<~DOC
        This command imports transaction histories from all available sources defined in the
        config and saves them in CSV or JSON files in the `data` directory.

        You can pass one or more source names as arguments to import transactions only from these
        sources. Add a caret character (^) before a source name to import all sources except this one.
        If no arguments are added, all defined sources will be imported.
      DOC

      run do |opts, args, cmd|
        filter = CLI.source_filter(args)

        task = ImportTask.new(CLI.config)
        task.run(filter)
      end
    end

    App.define_command('build') do
      summary 'Merge all transaction histories and save or process them as a single list'
      usage 'build <output_type>'
      description <<~DOC
        This command reads all imported transaction histories from the files configured in
        the config, merges them into one unified transaction history, and then performs a selected
        task on the combined list. Depending on the task this means either saving the processed list
        to a new file in a specific format, or calculating some kind of summary from all the data.

        Available output types:

        list - A simple list, one line per transaction in a unified format (build/list.csv)

        split-list - A list with all crypto-to-crypto transactions split into a separate buy
        and sell (build/split-list.csv)

        raw - Like list, but in a format potentially more suitable for further processing with
        other tools (build/raw.csv)

        summary - Calculates the final balance of each currency you should have at the moment
        according to the transaction history
      DOC

      run do |opts, args, cmd|
        output_name, *rest = args

        if output_name
          task = BuildTask.new(CLI.config)
          task.run(output_name, rest)
        else
          puts cmd.help
        end
      end
    end

    App.define_command('run') do
      summary 'Execute a custom action from one of the configured importers'
      usage 'run <source> <command> [args]'
      description <<~DOC
        Some importers may have custom commands implemented that only make sense for a given
        importer. This allows you to run these commands from the command line.
      DOC

      run do |opts, args, cmd|
        puts cmd.help
      end
    end
  end
end
