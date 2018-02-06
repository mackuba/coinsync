require 'csv'
require 'time'

require_relative '../currencies'
require_relative '../transaction'

module CoinSync
  module Importers
    class Kraken
      class LedgerEntry
        attr_accessor :txid, :refid, :time, :type, :aclass, :asset, :amount, :fee, :balance

        def initialize(line)
          @txid = line[0]
          @refid = line[1]
          @time = Time.parse(line[2] + " +0000")
          @type = line[3]
          @aclass = line[4]
          @asset = parse_currency(line[5])
          @amount = line[6].to_f
          @fee = line[7].to_f
          @balance = line[8].to_f
        end

        def parse_currency(code)
          case code
          when 'BCH' then CryptoCurrency.new('BCH')
          when 'XETC' then CryptoCurrency.new('ETC')
          when 'XETH' then CryptoCurrency.new('ETH')
          when 'XICN' then CryptoCurrency.new('ICN')
          when 'XLTC' then CryptoCurrency.new('LTC')
          when 'XXBT' then CryptoCurrency.new('BTC')
          when 'XXLM' then CryptoCurrency.new('XLM')
          when 'XXMR' then CryptoCurrency.new('XMR')
          when 'XXRP' then CryptoCurrency.new('XRP')
          when 'ZEUR' then FiatCurrency.new('EUR')
          when 'ZUSD' then FiatCurrency.new('USD')
          else raise "Unknown currency: #{code}"
          end
        end

        def crypto?
          @asset.is_a?(CryptoCurrency)
        end
      end

      def read_transaction_list(source)
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

          if crypto.nil?
            raise "Kraken importer error: Couldn't match a pair of ledger lines"
          elsif fiat.nil?
            # skip for now
            matching = nil
            next
          end

          if crypto.amount > 0
            transactions << Transaction.new(
              exchange: 'Kraken',
              bought_currency: crypto.asset,
              sold_currency: fiat.asset,
              time: crypto.time,
              bought_amount: crypto.amount - crypto.fee,
              sold_amount: -(fiat.amount - fiat.fee)
            )
          elsif crypto.amount < 0
            transactions << Transaction.new(
              exchange: 'Kraken',
              bought_currency: fiat.asset,
              sold_currency: crypto.asset,
              time: crypto.time,
              bought_amount: fiat.amount - fiat.fee,
              sold_amount: -(crypto.amount - crypto.fee)
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
