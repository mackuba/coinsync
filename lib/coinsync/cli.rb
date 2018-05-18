require 'clamp'

require_relative 'balance_task'
require_relative 'build_task'
require_relative 'config'
require_relative 'import_task'
require_relative 'run_command_task'
require_relative 'source_filter'
require_relative 'version'

module CoinSync
  class CLI < Clamp::Command
    module GlobalOptions
      def self.included(base)
        base.option ['-c', '--config'], 'CONFIG_FILE', 'path to a custom config file', attribute_name: 'config_file'
      end
    end

    include GlobalOptions

    option "--version", :flag, "Show version" do
      puts CoinSync::VERSION
      exit
    end


    class Command < Clamp::Command
      include GlobalOptions

      def config
        Config.load_from_file(config_file)
      end

      def parse_sources(args)
        SourceFilter.new.parse_command_line_args(args)
      end
    end

    class BalanceCommand < Command
      parameter '[SOURCE] ...', 'specific sources to check balance on'

      def execute
        selected, except = parse_sources(source_list)
        task = BalanceTask.new(config)
        task.run(selected, except)
      end
    end

    class ImportCommand < Command
      parameter '[SOURCE] ...', 'specific sources to import'

      def execute
        selected, except = parse_sources(source_list)
        task = ImportTask.new(config)
        task.run(selected, except)
      end
    end

    class BuildCommand < Command
      parameter 'OUTPUT', 'selected task to perform on the combined list'

      def execute
        task = BuildTask.new(config)
        task.run(output, args)
      end
    end

    class RunCommand < Command
      parameter 'SOURCE', 'name of a configured source'
      parameter 'COMMAND', 'name of a command defined for that source'

      def execute
        task = RunCommandTask.new(config)
        task.run(source, command, args)
      end
    end

    subcommand 'balance', 'Import and print wallet balances from all or selected sources', BalanceCommand
    subcommand 'import', 'Import transaction histories from all or selected sources', ImportCommand
    subcommand 'build', 'Merge all transaction histories and then save or process them as a single list', BuildCommand
    subcommand 'run', 'Execute a custom action from one of the configured importers', RunCommand
  end
end
