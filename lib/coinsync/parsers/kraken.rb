require 'csv'
require 'time'
require_relative '../transaction'

module CoinSync
  module Parsers
    class Kraken
      class LedgerEntry
        attr_accessor :txid, :refid, :time, :type, :aclass, :asset, :amount, :fee, :balance

        def initialize(line)
          @txid = line[0]
          @refid = line[1]
          @time = Time.parse(line[2])
          @type = line[3]
          @aclass = line[4]
          @asset = line[5]
          @amount = line[6].to_f
          @fee = line[7].to_f
          @balance = line[8].to_f
        end

        def crypto?
          @asset != 'ZEUR'
        end
      end

      def process(source)
        csv = CSV.new(source, col_sep: ',')

        matching = nil
        transactions = []

        csv.each do |line|
          next if line[0] == 'txid'

          entry = LedgerEntry.new(line)

          next if entry.type != 'trade'

          if matching.nil?
            matching = entry
            next
          end

          if matching.refid != entry.refid
            raise "Kraken importer error: Couldn't match a pair of ledger lines"
          end

          fiat = [matching, entry].detect { |e| !e.crypto? }
          crypto = [matching, entry].detect { |e| e.crypto? }

          if fiat.nil? || crypto.nil?
            raise "Kraken importer error: Couldn't match a pair of ledger lines"
          end

          if crypto.amount > 0
            transactions << Transaction.new(
              lp: 0,
              source: 'Kraken',
              type: 'Kup',
              date: crypto.time,
              btc_amount: crypto.amount - crypto.fee,
              price: -(fiat.amount - fiat.fee) / (crypto.amount - crypto.fee)
            )
          elsif crypto.amount < 0
            transactions << Transaction.new(
              lp: 0,
              source: 'Kraken',
              type: 'Sprzedaj',
              date: crypto.time,
              btc_amount: -(crypto.amount - crypto.fee),
              price: (fiat.amount - fiat.fee) / -(crypto.amount - crypto.fee)
            )
          else
            raise "Kraken importer error: unexpected amount 0"
          end

          matching = nil
        end

        transactions
      end
    end
  end
end
