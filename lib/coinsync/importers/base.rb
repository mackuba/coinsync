require 'cri'

module CoinSync
  module Importers
    def self.registered
      @importers ||= {}
    end

    class Base
      class Command < Cri::Command
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

      def self.define_command(name, &block)
        commands[name.to_sym] = block
      end

      def initialize(config, params = {})
        @config = config
        @params = params
      end

      def can_build?
        true
      end

      def command(name)
        if block = self.class.commands[name.to_sym]
          dsl = Cri::CommandDSL.new(Command.new(self))
          dsl.instance_eval(&block)
          dsl.run do |opts, args, cmd|
            cmd.importer.send(name, opts, args, cmd)
          end
          dsl.command
        else
          nil
        end
      end
    end
  end
end
