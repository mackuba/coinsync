require 'csv'

require_relative 'base'
require_relative 'kraken_common'

module CoinSync
  module Importers
    class KrakenCSV < Base
      register_importer :kraken_csv

      include Kraken::Common

      def read_transaction_list(source)
        csv = CSV.new(source, col_sep: ',')

        entries = []

        csv.each do |line|
          next if line[0] == 'txid'

          entries << Kraken::LedgerEntry.from_csv(line)
        end

        build_transaction_list(entries)
      end
    end
  end
end
