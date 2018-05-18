require 'cri'
require_relative 'cri_hax'

require_relative 'balance_task'
require_relative 'build_task'
require_relative 'config'
require_relative 'import_task'
require_relative 'run_command_task'
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
      optional :c, :config, 'path to a custom config file'

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
      usage 'lsadfkasfdh'
      summary 'a tool for importing and processing data from cryptocurrency exchanges'
      description 'whatevers'

      optional :c, :config, 'path to a custom config file'

      flag :h, :help, 'show help for this command' do |value, cmd|
        puts cmd.help
        exit 0
      end
    end

    App.define_command('balance') do
      summary 'import and print wallet balances from all or selected sources'
      usage 'LBLBLblbldfbsdfbl'
      
      option :f, :format, 'format to use'

      # TODO description ''
      #   parameter '[SOURCE] ...', 'specific sources to check balance on'

      run do |opts, args, cmd|
        selected, except = CLI.parse_sources(args)

        task = BalanceTask.new(CLI.config)
        task.run(selected, except)
      end
    end

    App.define_command('import') do
      summary 'import and print wallet balances from all or selected sources'
      usage 'LBLBLblbldfbsdfbl'
      # TODO description ''
      #   parameter '[SOURCE] ...', 'specific sources to import'

      run do |opts, args, cmd|
        selected, except = CLI.parse_sources(args)

        task = ImportTask.new(CLI.config)
        task.run(selected, except)
      end
    end

    App.define_command('build') do
      summary 'merge all transaction histories and save or process them as a single list'
      usage 'LBLBLblbldfbsdfbl'
      # TODO description ''
      #   parameter 'OUTPUT', 'selected task to perform on the combined list'

      run do |opts, args, cmd|
        output_name, *rest = args

        task = BuildTask.new(CLI.config)
        task.run(output_name, rest)
      end
    end

    App.define_command('run') do
      summary 'execute a custom action from one of the configured importers'
      usage 'LBLBLblbldfbsdfbl'

      # TODO description ''
      #   parameter 'SOURCE', 'name of a configured source'
      #   parameter 'COMMAND', 'name of a command defined for that source'
    end
  end
end
