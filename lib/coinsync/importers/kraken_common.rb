require 'bigdecimal'
require 'time'

require_relative '../currencies'
require_relative '../transaction'

module CoinSync
  module Importers
    module Kraken
      class LedgerEntry
        attr_accessor :txid, :refid, :time, :type, :aclass, :asset, :amount, :fee, :balance

        def self.from_csv(line)
          entry = self.new
          entry.txid = line[0]
          entry.refid = line[1]
          entry.time = Time.parse(line[2] + " +0000")
          entry.type = line[3]
          entry.aclass = line[4]
          entry.asset = parse_currency(line[5])
          entry.amount = BigDecimal.new(line[6])
          entry.fee = BigDecimal.new(line[7])
          entry.balance = BigDecimal.new(line[8])
          entry
        end

        def self.from_json(hash)
          entry = self.new
          entry.refid = hash['refid']
          entry.time = Time.at(hash['time'])
          entry.type = hash['type']
          entry.aclass = hash['aclass']
          entry.asset = parse_currency(hash['asset'])
          entry.amount = BigDecimal.new(hash['amount'])
          entry.fee = BigDecimal.new(hash['fee'])
          entry.balance = BigDecimal.new(hash['balance'])
          entry
        end

        def self.parse_currency(code)
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
          @asset.crypto?
        end
      end

      module Common
        def build_transaction_list(entries)
          set = []
          transactions = []

          entries.each do |entry|
            if entry.type == 'transfer'
              transactions << Transaction.new(
                exchange: 'Kraken',
                time: entry.time,
                bought_amount: entry.amount,
                bought_currency: entry.asset,
                sold_amount: BigDecimal(0),
                sold_currency: FiatCurrency.new(nil)
              )
              next
            end

            next if entry.type != 'trade'

            set << entry
            next unless set.length == 2

            if set[0].refid != set[1].refid
              raise "Kraken importer error: Couldn't match a pair of ledger lines - ids don't match: #{set}"
            end

            if set.none? { |e| e.crypto? }
              raise "Kraken importer error: Couldn't match a pair of ledger lines - " +
                "no cryptocurrencies were exchanged: #{set}"
            end

            bought = set.detect { |e| e.amount > 0 }
            sold = set.detect { |e| e.amount < 0 }

            if bought.nil? || sold.nil?
              raise "Kraken importer error: Couldn't match a pair of ledger lines - invalid transaction amounts: #{set}"
            end

            transactions << Transaction.new(
              exchange: 'Kraken',
              time: [bought.time, sold.time].max,
              bought_amount: bought.amount - bought.fee,
              bought_currency: bought.asset,
              sold_amount: -(sold.amount - sold.fee),
              sold_currency: sold.asset
            )

            set.clear
          end

          transactions
        end
      end
    end
  end
end
