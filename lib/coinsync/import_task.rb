require 'fileutils'

require_relative 'importers/all'

module CoinSync
  class ImportTask
    def initialize(config)
      @config = config
    end

    def run(selected = nil, except = nil)
      sources = if selected.nil? || selected.empty?
        @config.sources.values
      else
        selected = [selected] unless selected.is_a?(Array)

        selected.map do |key|
          @config.sources[key] or raise "Source not found in the config file: '#{key}'"
        end
      end

      if except
        except = [except] unless except.is_a?(Array)
        sources -= except.map { |key| @config.sources[key] }
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
