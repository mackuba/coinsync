require 'cri'

require_relative 'balance_task'
require_relative 'build_task'
require_relative 'config'
require_relative 'import_task'
require_relative 'run_command_task'
require_relative 'source_filter'
require_relative 'version'

# temporary (?) hack to allow ignoring unknown options
class Cri::OptionParser
  def run
    @running = true

    while running?
      # Get next item
      e = @unprocessed_arguments_and_options.shift
      break if e.nil?

      begin
        if e == '--'
          handle_dashdash(e)
        elsif e =~ /^--./ && !@no_more_options
          handle_dashdash_option(e)
        elsif e =~ /^-./ && !@no_more_options
          handle_dash_option(e)
        else
          add_argument(e)
        end
      rescue IllegalOptionError
        add_argument(e)
      end
    end

    add_defaults

    self
  ensure
    @running = false
  end
end

module CoinSync
  module CLI
    App = Cri::Command.define do
      name 'coinsync'
      usage 'lsadfkasfdh'
      summary 'a tool for importing and processing data from cryptocurrency exchanges'
      description 'whatevers'

      optional :c, :config, 'path to a custom config file'

      flag :h, :help, 'show help for this command' do |value, cmd|
        puts cmd.help
        exit 0
      end
    end

    class << self
      def load_config(opts)
        Config.load_from_file(opts[:config])
      end

      def parse_sources(args)
        SourceFilter.new.parse_command_line_args(args)
      end
    end

  #   option "--version", :flag, "Show version" do
  #     puts CoinSync::VERSION
  #     exit
  #   end

    App.define_command('balance') do
      summary 'import and print wallet balances from all or selected sources'
      usage 'LBLBLblbldfbsdfbl'
      # TODO description ''
      #   parameter '[SOURCE] ...', 'specific sources to check balance on'

      run do |opts, args, cmd|
        config = CLI.load_config(opts)
        selected, except = CLI.parse_sources(args)

        task = BalanceTask.new(config)
        task.run(selected, except)
      end
    end

    App.define_command('import') do
      summary 'import and print wallet balances from all or selected sources'
      usage 'LBLBLblbldfbsdfbl'
      # TODO description ''
      #   parameter '[SOURCE] ...', 'specific sources to import'

      run do |opts, args, cmd|
        config = CLI.load_config(opts)
        selected, except = CLI.parse_sources(args)

        task = ImportTask.new(config)
        task.run(selected, except)
      end
    end

    App.define_command('build') do
      summary 'merge all transaction histories and save or process them as a single list'
      usage 'LBLBLblbldfbsdfbl'
      # TODO description ''
      #   parameter 'OUTPUT', 'selected task to perform on the combined list'

      run do |opts, args, cmd|
        config = CLI.load_config(opts)
        output_name, *rest = args

        task = BuildTask.new(config)
        task.run(output_name, rest)
      end
    end

    App.define_command('run') do
      summary 'execute a custom action from one of the configured importers'
      usage 'LBLBLblbldfbsdfbl'
      # TODO description ''
      #   parameter 'SOURCE', 'name of a configured source'
      #   parameter 'COMMAND', 'name of a command defined for that source'

      run do |opts, args, cmd|
        config = CLI.load_config(opts)
        source, command, *rest = args
 
        if source.nil? || command.nil?
          puts "Usage: coinsync run <source> <command> [args]"
          exit 1
        end

        task = RunCommandTask.new(config)
        task.run(source, command, rest)
      end
    end
  end
end
