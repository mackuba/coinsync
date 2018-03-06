require 'fileutils'

require_relative 'importers/all'

module CoinSync
  class ImportTask
    def initialize(config)
      @config = config
    end

    def run(selected = nil, except = nil)
      sources = if selected.nil? || selected.empty?
        @config.sources
      else
        selected = [selected] unless selected.is_a?(Array)

        selected.map do |searched_key|
          found = @config.sources.detect { |source| source.key == searched_key }
          found or raise "Source not found in the config file: '#{searched_key}'"
        end
      end

      if except
        except = [except] unless except.is_a?(Array)
        sources = sources.reject { |source| except.include?(source.key) }
      end

      sources.each do |source|
        importer = source.importer
        key = source.key
        filename = source.filename

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
