require 'bigdecimal'
require 'csv'

require_relative '../formatter'
require_relative '../table_printer'
require_relative '../transaction'

module CoinSync
  module Outputs
    class Fifo
      class TransactionFragment < SimpleDelegator
        attr_reader :amount_left, :transaction

        def initialize(transaction)
          super(transaction)

          @transaction = transaction
          @amount_left = transaction.crypto_amount
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
        @config = config
        @target_file = target_file
        @formatter = Formatter.new(config)
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
              inputs[tx.bought_currency] << TransactionFragment.new(tx)
              csv << transaction_to_csv(tx)
            when Transaction::TYPE_SALE
              current_sale = TransactionFragment.new(tx)
              inputs[tx.sold_currency] ||= []

              while current_sale.amount_left > 0
                input = inputs[tx.sold_currency].first
                raise "Error: no inputs left to sell for #{tx.sold_currency.code}" if input.nil?

                partial_sale = sell_input(input, current_sale)
                csv << transaction_to_csv(partial_sale, input.transaction)
                inputs[tx.sold_currency].shift if input.amount_left == 0

                total_cost = converted(input).price * partial_sale.crypto_amount
                total_gain = converted(partial_sale).fiat_amount

                years[tx.time.year] ||= [BigDecimal(0), BigDecimal(0)]
                years[tx.time.year][0] += total_gain
                years[tx.time.year][1] += total_cost
              end
            else
              raise "Fifo: transaction type not currently supported"
            end
          end
        end

        print_year_stats(years)
      end

      def sell_input(input, sale)
        if converted(sale).bought_currency != converted(input).sold_currency
          raise "Error: currencies don't match: bought with #{input.sold_currency.code}, " +
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
          'Purchase no.',
          'Purchase price',
          'Purchase cost',
          'Sale value',
          'Profit'
        ]

        line
      end

      def transaction_to_csv(tx, input = nil)
        raise "Currently unsupported" if tx.swap?
        raise "Transaction should have a number assigned: #{tx}" if tx.number.nil?
        raise "Transaction should have a number assigned: #{input}" if input && input.number.nil?

        asset = tx.crypto_currency.code
        currency = tx.fiat_currency.code
        tx_type = tx.type.to_s.capitalize

        csv = [
          tx.number,
          tx.exchange,
          @config.translate(tx_type),
          @formatter.format_time(tx.time),
          @formatter.format_crypto(tx.crypto_amount),
          asset,
          @formatter.format_fiat(tx.fiat_amount),
          @formatter.format_fiat_price(tx.price),
          currency || '–'
        ]

        if @config.convert_to_currency
          if tx.converted
            csv += [
              @formatter.format_fiat(tx.converted.fiat_amount),
              @formatter.format_fiat_price(tx.converted.price),
              tx.converted.exchange_rate && @formatter.format_decimal(tx.converted.exchange_rate, precision: 4)
            ]
          else
            csv += [
              @formatter.format_fiat(tx.fiat_amount),
              @formatter.format_fiat_price(tx.price),
              nil
            ]
          end
        end

        if input
          purchase_price = converted(input).price
          total_cost = purchase_price * tx.crypto_amount
          total_gain = converted(tx).fiat_amount

          csv += [
            input.number,
            @formatter.format_fiat_price(purchase_price),
            @formatter.format_fiat(total_cost),
            @formatter.format_fiat(total_gain),
            @formatter.format_fiat(total_gain - total_cost)
          ]
        end

        csv
      end

      def print_year_stats(years)
        header = ['Year', 'Cost', 'Gain', 'Profit']
        rows = []

        years.keys.sort.each do |year|
          gain, cost = years[year]
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
