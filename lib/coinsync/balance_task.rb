require_relative 'balance'
require_relative 'formatter'
require_relative 'importers/all'

module CoinSync
  class BalanceTask
    def initialize(config)
      @config = config
      @formatter = Formatter.new(config)
    end

    def run
      totals = {}

      @config.sources.each do |importer, key, params, filename|
        if importer.respond_to?(:can_import?)
          if importer.can_import?
            puts "[#{key}] Importing balances... "

            importer.import_balances.each do |balance|
              totals[balance.currency] ||= Balance.new(balance.currency)
              totals[balance.currency] += balance

              puts "  #{balance.currency.code}: " +
                "#{@formatter.format_crypto(balance.available)} " +
                "(+ #{@formatter.format_crypto(balance.locked)})"
            end
          else
            puts "[#{key}] Skipping import"
          end
        end
      end

      puts "Total:"

      totals.each do |currency, balance|
        puts "  #{currency.code}: " +
          "#{@formatter.format_crypto(balance.available)} " +
          "(+ #{@formatter.format_crypto(balance.locked)})"
      end
    end
  end
end
