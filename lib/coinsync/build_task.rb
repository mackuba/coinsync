require 'fileutils'

require_relative 'builder'
require_relative 'currency_converter'
require_relative 'outputs/all'

module CoinSync
  class BuildTask
    def initialize(config)
      @config = config
    end

    def run(output_name, args = [])
      if output_name.nil?
        puts "Error: Build task name not given"
        exit 1
      end

      output_class = Outputs.registered[output_name.to_sym]

      if output_class.nil?
        puts "Unknown build task: #{output_name}"
        exit 1
      end

      FileUtils.mkdir_p 'build'

      builder = Builder.new(@config)
      transactions = builder.build_transaction_list

      output = output_class.new(@config, "build/#{output_name}.csv")

      if output.requires_currency_conversion?
        if options = @config.currency_conversion
          converter = CurrencyConverter.new(options)
          converter.process_transactions(transactions)
        end
      end

      output.process_transactions(transactions, *args)
    end
  end
end
