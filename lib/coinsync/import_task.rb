require 'fileutils'

require_relative 'importers/all'

module CoinSync
  class ImportTask
    def initialize(config)
      @config = config
    end

    def run
      @config.sources.each do |importer, key, params, filename|
        if importer.respond_to?(:can_import?)
          if importer.can_import?
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
