require 'bigdecimal'
require 'csv'

require_relative 'base'
require_relative '../formatter'
require_relative '../table_printer'
require_relative '../transaction'

module CoinSync
  module Outputs
    class Fifo < Base
      register_output :fifo

      class TransactionCSV < Struct.new(:csv, :cost, :gain)
      end

      class TransactionFragment < SimpleDelegator
        attr_reader :amount_left, :transaction, :input_chain

        def initialize(direction, transaction, previous_input = nil)
          super(transaction)

          @transaction = transaction

          case direction
          when :purchase
            @amount_left = transaction.bought_amount
            @input_chain = [transaction] + (previous_input&.input_chain || [])
          when :sale
            @amount_left = transaction.sold_amount
          else
            raise "Unexpected direction: #{direction}"
          end
        end

        def original_input
          input_chain.last
        end

        def sell(amount)
          unless amount <= @amount_left
            f = Formatter.new
            raise "TransactionFragment: cannot sell #{f.format_crypto(amount)}, " +
              "only #{f.format_crypto(@amount_left)} left"
          end

          @amount_left -= amount
        end
      end

      def initialize(config, target_file)
        super
        @formatter = Formatter.new(config)
      end

      def requires_currency_conversion?
        true
      end

      def process_transactions(transactions)
        years = {}

        CSV.open(@target_file, 'w', col_sep: @config.column_separator) do |csv|
          inputs = {}

          csv << headers

          transactions.each do |tx|
            case tx.type
            when Transaction::TYPE_PURCHASE
              inputs[tx.bought_currency] ||= []
              inputs[tx.bought_currency] << TransactionFragment.new(:purchase, tx)
              csv << transaction_csv(tx).csv
            when Transaction::TYPE_SALE
              current_sale = TransactionFragment.new(:sale, tx)
              inputs[tx.sold_currency] ||= []
              sub_id = 1

              while current_sale.amount_left > 0
                input = inputs[tx.sold_currency].first
                raise "Error: no inputs left to sell for #{tx.sold_currency.code}" if input.nil?

                partial_sale = sell_input(input, current_sale)
                partial_sale.number = "#{tx.number}.#{sub_id}" unless sub_id == 1 && current_sale.amount_left == 0

                result = transaction_csv(partial_sale, input)
                csv << result.csv

                inputs[tx.sold_currency].shift if input.amount_left == 0
                sub_id += 1

                years[tx.time.year] ||= [BigDecimal(0), BigDecimal(0)]
                years[tx.time.year][0] += result.cost
                years[tx.time.year][1] += result.gain
              end
            when Transaction::TYPE_SWAP
              current_sale = TransactionFragment.new(:sale, tx)
              inputs[tx.bought_currency] ||= []
              inputs[tx.sold_currency] ||= []
              sub_id = 1

              while current_sale.amount_left > 0
                input = inputs[tx.sold_currency].first
                raise "Error: no inputs left to sell for #{tx.sold_currency.code}" if input.nil?

                partial_sale = swap_input(input, current_sale)
                partial_sale.number = "#{tx.number}.#{sub_id}" unless sub_id == 1 && current_sale.amount_left == 0

                result = transaction_csv(partial_sale, input)
                csv << result.csv

                inputs[tx.sold_currency].shift if input.amount_left == 0
                sub_id += 1

                inputs[tx.bought_currency] << TransactionFragment.new(:purchase, partial_sale, input)
              end
            else
              raise "Fifo: unknown transaction type #{tx.type}"
            end
          end
        end

        print_year_stats(years)
      end

      def sell_input(input, sale)
        if converted(sale).bought_currency != converted(input.original_input).sold_currency
          raise "Error: currencies don't match: bought with #{input.original_input.sold_currency.code}, " +
            "sold with #{sale.bought_currency.code}. Use `convert_to` option if multiple fiat currencies were used."
        end

        amount = [input.amount_left, sale.amount_left].min

        input.sell(amount)
        sale.sell(amount)

        tx = Transaction.new(
          number: sale.number,
          exchange: sale.exchange,
          bought_currency: sale.bought_currency,
          sold_currency: sale.sold_currency,
          time: sale.time,
          bought_amount: amount * sale.price,
          sold_amount: amount
        )

        if sale.converted
          tx.converted = Transaction::ConvertedAmounts.new
          tx.converted.exchange_rate = sale.converted.exchange_rate
          tx.converted.bought_currency = sale.converted.bought_currency
          tx.converted.bought_amount = tx.bought_amount * tx.converted.exchange_rate
          tx.converted.sold_currency = sale.sold_currency
          tx.converted.sold_amount = tx.sold_amount
        end

        tx
      end

      def swap_input(input, sale)
        amount = [input.amount_left, sale.amount_left].min

        input.sell(amount)
        sale.sell(amount)

        tx = Transaction.new(
          number: sale.number,
          exchange: sale.exchange,
          bought_currency: sale.bought_currency,
          sold_currency: sale.sold_currency,
          time: sale.time,
          bought_amount: amount / sale.sold_amount * sale.bought_amount,
          sold_amount: amount
        )

        tx
      end

      def headers
        line = [
          'No.',
          'Exchange',
          'Type',
          'Date',
          'Amount',
          'Asset',
          'Total value',
          'Price',
          'Currency'
        ].map { |l| @config.translate(l) }

        if currency = @config.convert_to_currency
          line += [
            @config.translate('Total value ($CURRENCY)').gsub('$CURRENCY', currency.code),
            @config.translate('Price ($CURRENCY)').gsub('$CURRENCY', currency.code),
            @config.translate('Exchange rate')
          ]
        end

        line += [
          'Originating transaction(s)',
          nil, nil, nil, nil, nil,
          'Amount of original asset',
          'Purchase price',
          'Purchase cost',
          'Sale value',
          'Profit'
        ].map { |l| @config.translate(l) }

        line
      end

      def transaction_csv(tx, input = nil)
        ([tx] + (input&.input_chain || [])).each do |transaction|
          if transaction.number.nil?
            raise "Transaction should have a number assigned: #{transaction}"
          end
        end

        tx_type = tx.type.to_s.capitalize

        csv = [
          tx.number,
          tx.exchange,
          @config.translate(tx_type),
          @formatter.format_time(tx.time)
        ]

        if tx.purchase? || tx.sale?
          csv += [
            @formatter.format_crypto(tx.crypto_amount),
            tx.crypto_currency.code,
            @formatter.format_fiat(tx.fiat_amount),
            @formatter.format_fiat_price(tx.price),
            tx.fiat_currency.code || '–'
          ]
        else
          csv += [
            @formatter.format_crypto(tx.bought_amount),
            tx.bought_currency.code,
            @formatter.format_crypto(tx.sold_amount),
            nil,
            tx.sold_currency.code
          ]
        end

        if @config.convert_to_currency
          if tx.converted
            csv += [
              @formatter.format_fiat(tx.converted.fiat_amount),
              @formatter.format_fiat_price(tx.converted.price),
              tx.converted.exchange_rate && @formatter.format_float(tx.converted.exchange_rate, precision: 4)
            ]
          elsif !tx.swap?
            csv += [
              @formatter.format_fiat(tx.fiat_amount),
              @formatter.format_fiat_price(tx.price),
              nil
            ]
          else
            csv += [nil, nil, nil]
          end
        end

        total_cost = BigDecimal.new(0)
        total_gain = BigDecimal.new(0)

        if input
          chain = input.input_chain
          mid_steps = input.input_chain[0...-1]
          original = input.original_input

          step_lines = chain.map { |step|
            [
              step.number,
              @formatter.format_crypto(step.bought_amount),
              step.bought_currency.code,
              '<=',
              step.sold_currency.crypto? ?
                @formatter.format_crypto(step.sold_amount) : @formatter.format_fiat(step.sold_amount),
              step.sold_currency.code || '–'
            ]
          }

          if @config.convert_to_currency && original.converted && original.sold_currency.code
            step_lines << [
              nil, nil, nil, '=',
              @formatter.format_fiat(original.converted.sold_amount),
              original.converted.sold_currency.code
            ]
          end

          csv += step_lines.transpose.map { |cells| cells.join("\n") }

          unless tx.swap?
            purchase_price = converted(original).price
            fraction = tx.crypto_amount * mid_steps.inject(1) { |sum, tx| sum * tx.sold_amount / tx.bought_amount }
            total_cost = purchase_price * fraction
            total_gain = converted(tx).fiat_amount

            csv += [
              @formatter.format_crypto(fraction),
              @formatter.format_fiat_price(purchase_price),
              @formatter.format_fiat(total_cost),
              @formatter.format_fiat(total_gain),
              @formatter.format_fiat(total_gain - total_cost)
            ]
          end
        end

        TransactionCSV.new(csv, total_cost, total_gain)
      end

      def print_year_stats(years)
        header = ['Year', 'Cost', 'Gain', 'Profit']
        rows = []

        years.keys.sort.each do |year|
          cost, gain = years[year]
          rows << [
            year.to_s,
            @formatter.format_fiat(cost),
            @formatter.format_fiat(gain),
            @formatter.format_fiat(gain - cost)
          ]
        end

        printer = TablePrinter.new
        printer.print_table(header, rows, alignment: [:ljust, :rjust, :rjust, :rjust], separator: '    ')
      end

      def converted(transaction)
        transaction.converted || transaction
      end
    end
  end
end
