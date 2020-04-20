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
          when 'ADA' then CryptoCurrency.new('ADA')
          when 'BCH' then CryptoCurrency.new('BCH')
          when 'BSV' then CryptoCurrency.new('BSV')
          when 'DASH' then CryptoCurrency.new('DASH')
          when 'EOS' then CryptoCurrency.new('EOS')
          when 'GNO' then CryptoCurrency.new('GNO')
          when 'KFEE' then CryptoCurrency.new('KFEE')
          when 'QTUM' then CryptoCurrency.new('QTUM')
          when 'USDT' then CryptoCurrency.new('USDT')
          when 'XTZ' then CryptoCurrency.new('XTZ')

          when 'XDAO' then CryptoCurrency.new('DAO')
          when 'XETC' then CryptoCurrency.new('ETC')
          when 'XETH' then CryptoCurrency.new('ETH')
          when 'XICN' then CryptoCurrency.new('ICN')
          when 'XLTC' then CryptoCurrency.new('LTC')
          when 'XMLN' then CryptoCurrency.new('MLN')
          when 'XNMC' then CryptoCurrency.new('NMC')
          when 'XREP' then CryptoCurrency.new('REP')
          when 'XXBT' then CryptoCurrency.new('BTC')
          when 'XXDG' then CryptoCurrency.new('DOGE')
          when 'XXLM' then CryptoCurrency.new('XLM')
          when 'XXMR' then CryptoCurrency.new('XMR')
          when 'XXRP' then CryptoCurrency.new('XRP')
          when 'XXVN' then CryptoCurrency.new('VEN')
          when 'XZEC' then CryptoCurrency.new('ZEC')

          when 'ZCAD' then FiatCurrency.new('CAD')
          when 'ZEUR' then FiatCurrency.new('EUR')
          when 'ZGBP' then FiatCurrency.new('GBP')
          when 'ZJPY' then FiatCurrency.new('JPY')
          when 'ZKRW' then FiatCurrency.new('KRW')
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
          previous = nil
          transactions = []

          entries.each do |entry|
            next if entry.type != 'transfer' && entry.type != 'trade'

            if previous.nil?
              previous = entry
              next
            elsif previous.type == 'transfer'
              if entry.type == 'transfer' && (matched_transaction = try_match_transfer(previous, entry))
                transactions << matched_transaction
                previous = nil
              else
                transactions << make_airdrop_transaction(previous)
                previous = entry
              end
            else
              if entry.type == 'trade'
                matched_transaction = match_trade(previous, entry)
                transactions << matched_transaction
                previous = nil
              else
                raise "Kraken importer error: Couldn't match ledger lines - unmatched trade followed by transfer"
              end
            end
          end

          transactions
        end

        def make_airdrop_transaction(entry)
          Transaction.new(
            exchange: 'Kraken',
            time: entry.time,
            bought_amount: entry.amount,
            bought_currency: entry.asset,
            sold_amount: BigDecimal(0),
            sold_currency: FiatCurrency.new(nil)
          )
        end

        def try_match_transfer(first, second)
          pair = [first, second]

          return nil if second.time - first.time > 10

          bought = pair.detect { |e| e.amount > 0 }
          sold = pair.detect { |e| e.amount < 0 }

          return nil unless bought && sold && pair.all? { |e| e.crypto? }

          Transaction.new(
            exchange: 'Kraken',
            time: [bought.time, sold.time].max,
            bought_amount: bought.amount - bought.fee,
            bought_currency: bought.asset,
            sold_amount: -(sold.amount - sold.fee),
            sold_currency: sold.asset
          )
        end

        def match_trade(first, second)
          pair = [first, second]

          if first.refid != second.refid
            raise "Kraken importer error: Couldn't match a pair of ledger lines - ids don't match: #{pair}"
          end

          if pair.none? { |e| e.crypto? }
            raise "Kraken importer error: Couldn't match a pair of ledger lines - " +
              "no cryptocurrencies were exchanged: #{pair}"
          end

          bought = pair.detect { |e| e.amount > 0 }
          sold = pair.detect { |e| e.amount < 0 }

          if bought.nil? || sold.nil?
            raise "Kraken importer error: Couldn't match a pair of ledger lines - invalid transaction amounts: #{pair}"
          end

          Transaction.new(
            exchange: 'Kraken',
            time: [bought.time, sold.time].max,
            bought_amount: bought.amount - bought.fee,
            bought_currency: bought.asset,
            sold_amount: -(sold.amount - sold.fee),
            sold_currency: sold.asset
          )
        end
      end
    end
  end
end
