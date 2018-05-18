require 'cri'

module CoinSync
  module Importers
    def self.registered
      @importers ||= {}
    end

    class Base
      class ImporterCommand < Cri::Command
        attr_accessor :importer

        def initialize(importer)
          super()
          @importer = importer
        end
      end

      def self.register_importer(key)
        if Importers.registered[key]
          raise "Importer has already been registered at '#{key}'"
        else
          Importers.registered[key] = self
        end
      end

      def self.commands
        @commands ||= {}
      end

      def self.registered_commands
        commands.keys.compact
      end

      def self.define_command(name, &block)
        commands[name.to_sym] = block
      end

      def self.define_wrapper_command(&block)
        commands[nil] = block
      end

      def initialize(config, params = {})
        @config = config
        @params = params
      end

      def can_build?
        true
      end

      def registered_commands
        self.class.registered_commands
      end

      def wrapper_command(key)
        command = ImporterCommand.new(self)

        dsl = Cri::CommandDSL.new(command)
        dsl.name(key.to_s)
        dsl.description("Add a name of one of the custom commands listed below to run it on the given importer.")
        dsl.usage "#{key} <command> [options...]"
        dsl.run do |opts, args, cmd|
          puts cmd.help
        end

        if block = self.class.commands[nil]
          dsl.instance_eval(&block)
        end

        command
      end

      def command(name)
        if block = self.class.commands[name.to_sym]
          command = ImporterCommand.new(self)

          dsl = Cri::CommandDSL.new(command)
          dsl.name(name.to_s)
          dsl.usage(name.to_s)
          dsl.instance_eval(&block)

          run_block = command.block

          dsl.run do |opts, args, cmd|
            cmd.importer.instance_exec(opts, args, cmd, &run_block)
          end

          command
        else
          nil
        end
      end
    end
  end
end
