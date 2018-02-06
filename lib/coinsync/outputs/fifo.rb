require 'csv'

require_relative '../number_formatter'
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
          (amount <= @amount_left) or raise "TransactionFragment: cannot sell #{amount}, only #{@amount_left} left"

          @amount_left -= amount
        end
      end

      def initialize(config, target_file)
        @config = config
        @target_file = target_file
        @formatter = NumberFormatter.new(config)
      end

      def process_transactions(transactions)
        CSV.open(@target_file, 'w', col_sep: @config.column_separator) do |csv|
          inputs = []

          csv << headers

          transactions.each do |tx|
            case tx.type
            when Transaction::TYPE_PURCHASE
              inputs << TransactionFragment.new(tx)
              csv << transaction_to_csv(tx)
            when Transaction::TYPE_SALE
              current_sale = TransactionFragment.new(tx)

              while current_sale.amount_left > 0
                partial_sale = sell_input(inputs.first, current_sale)
                csv << transaction_to_csv(partial_sale, inputs.first.transaction)
                inputs.shift if inputs.first.amount_left == 0
              end
            else
              raise "Fifo: transaction type not currently supported"
            end
          end
        end
      end

      def sell_input(input, sale)
        if input.nil?
          raise "Error: input is nil for #{sale.to_line}"
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
          format_time(tx.time),
          @formatter.format_crypto(tx.crypto_amount),
          asset,
          @formatter.format_fiat(tx.fiat_amount),
          @formatter.format_fiat(tx.price),
          currency
        ]

        if @config.convert_to_currency
          if tx.converted
            csv += [
              @formatter.format_fiat(tx.converted.fiat_amount),
              @formatter.format_fiat(tx.converted.price),
              @formatter.format_float(tx.converted.exchange_rate, precision: 4)
            ]
          else
            csv += [
              @formatter.format_fiat(tx.fiat_amount),
              @formatter.format_fiat(tx.price),
              nil
            ]
          end
        end

        if input
          price = input.converted&.price || input.price
          total_cost = price * tx.crypto_amount
          total_gain = tx.converted&.fiat_amount || tx.fiat_amount

          csv += [
            input.number,
            @formatter.format_fiat(price),
            @formatter.format_fiat(total_cost),
            @formatter.format_fiat(total_gain),
            @formatter.format_fiat(total_gain - total_cost)
          ]
        end

        csv
      end

      def format_time(time)
        time.strftime(@config.time_format || '%Y-%m-%d %H:%M:%S')
      end
    end
  end
end
