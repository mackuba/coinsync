require_relative 'importers/all'

module CoinSync
  class RunCommandTask
    def initialize(config)
      @config = config
    end

    def run(source_name, command_name, args = [])
      source = @config.sources[source_name] or raise "Source not found in the config file: '#{source_name}'"
      importer = source.importer

      if command = importer.command(command_name)
        command.run(args)
      else
        raise "#{source_name}: no such command: #{command_name}"
      end
    end
  end
end
