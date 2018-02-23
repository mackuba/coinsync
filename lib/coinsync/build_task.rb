require 'fileutils'

require_relative 'builder'
require_relative 'currency_converter'
require_relative 'outputs/all'

module CoinSync
  class BuildTask
    def initialize(config)
      @config = config
    end

    def run(output_name)
      if output_name.nil?
        puts "Error: Build task name not given"
        exit 1
      end

      output_class = CoinSync::Outputs.registered[output_name.to_sym]

      if output_class.nil?
        puts "Unknown build task: #{output_name}"
        exit 1
      end

      FileUtils.mkdir_p 'build'

      builder = CoinSync::Builder.new(@config)
      transactions = builder.build_transaction_list

      output = output_class.new(@config, "build/#{output_name}.csv")

      if output.respond_to?(:requires_currency_conversion?) && output.requires_currency_conversion?
        if @config.convert_to_currency
          converter = CoinSync::CurrencyConverter.new(@config)
          converter.process_transactions(transactions)
        end
      end

      output.process_transactions(transactions)
    end
  end
end