require_relative 'balance'
require_relative 'formatter'
require_relative 'importers/all'

module CoinSync
  class BalanceTask
    def initialize(config)
      @config = config
      @formatter = Formatter.new(config)
    end

    def run(selected = nil, except = nil)
      balances = {}
      columns = []
      rows = []

      @config.filtered_sources(selected, except).each do |key, source|
        importer = source.importer

        if importer.respond_to?(:can_import?)
          if importer.can_import?
            print "[#{key}] Importing balances... "

            columns << key

            importer.import_balances.each do |balance|
              balances[balance.currency] ||= {}
              balances[balance.currency][key] = balance
              balances[balance.currency][nil] ||= Balance.new(balance.currency)
              balances[balance.currency][nil] += balance
            end

            puts "√"
          else
            puts "[#{key}] Skipping import"
          end
        end
      end

      columns.sort!

      balances.keys.sort.each do |coin|
        row = [coin.code, '|']
        row += columns.map { |e|
          available = balances[coin][e]&.available
          locked = balances[coin][e]&.locked
          available ? @formatter.format_crypto(available) + (locked > 0 ? ' (+)' : '') : ''
        }
        row << '|'
        row << @formatter.format_crypto(balances[coin][nil].available)
        rows << row
      end

      puts

      printer = TablePrinter.new
      printer.print_table(
        ['Coin', '|'] + columns + ['|', 'TOTAL'],
        rows,
        alignment: [:ljust, :center] + columns.map { |e| :rjust } + [:center, :rjust],
        separator: '   '
      )
    end
  end
end
