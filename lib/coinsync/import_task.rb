require 'fileutils'

require_relative 'importers/all'

module CoinSync
  class ImportTask
    def initialize(config)
      @config = config
    end

    def run(selected = nil)
      sources = if selected
        found = @config.sources.detect { |importer, key, params, filename| key == selected }
        raise "Source not found in the config file: '#{selected}'" if found.nil?
        [found]
      else
        @config.sources
      end

      sources.each do |importer, key, params, filename|
        if importer.respond_to?(:can_import?)
          if importer.can_import?
            if filename.nil?
              raise "No filename specified for '#{key}', please add a 'file' parameter."
            end

            print "[#{key}] Importing transactions... "

            FileUtils.mkdir_p(File.dirname(filename))
            importer.import_transactions(filename)

            puts "√"
          else
            puts "[#{key}] Skipping import"
          end
        end
      end

      puts "Done."
    end
  end
end