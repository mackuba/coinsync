require_relative 'importers/all'

module CoinSync
  class RunCommandTask
    def initialize(config)
      @config = config
    end

    def run(source_name, command, args = [])
      source = @config.sources[source_name] or raise "Source not found in the config file: '#{source_name}'"
      importer = source.importer

      if importer.class.registered_commands.include?(command.to_sym)
        importer.send(command.to_sym, *args)
      else
        raise "#{source_name}: no such command: #{command}"
      end
    end
  end
end
