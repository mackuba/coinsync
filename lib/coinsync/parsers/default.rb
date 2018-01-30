require_relative '../transaction'

module CoinSync
  module Parsers
    class Default
      def initialize(settings = {})
        @settings = settings
        @labels = @settings['labels'] || {}
      end

      def process(source)
      end

      def save_to_csv(tx)
        case tx.type
        when Transaction::TYPE_PURCHASE
          amount = tx.bought_amount
          total = tx.sold_amount
        when Transaction::TYPE_SALE
          amount = tx.sold_amount
          total = tx.bought_amount
        else
          raise "Currently unsupported"
        end

        tx_type = tx.type.to_s

        [
          tx.number || 0,
          tx.exchange,
          @labels[tx_type] || tx_type.capitalize,
          tx.time,
          format_float(amount, 8),
          format_float(total, 4),
          format_float(total / amount, 4)
        ]
      end

      private

      def format_float(value, prec)
        sprintf("%.#{prec}f", value).gsub(/\./, ',')
      end
    end
  end
end
