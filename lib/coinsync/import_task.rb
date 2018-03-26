require 'fileutils'

require_relative 'importers/all'

module CoinSync
  class ImportTask
    def initialize(config)
      @config = config
    end

    def run(selected = nil, except = nil)
      @config.filtered_sources(selected, except).each do |key, source|
        importer = source.importer
        filename = source.filename

        if importer.respond_to?(:can_import?)
          if importer.can_import?(:transactions)
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
