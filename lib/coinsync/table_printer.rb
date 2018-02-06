module CoinSync
  class TablePrinter
    def print_table(header, rows, alignment: nil, separator: '  ')
      rows.each do |row|
        if row.length != header.length
          raise "TablePrinter: All rows should have equal number of cells"
        end
      end

      ids = (0...header.length)
      widths = ids.map { |i| (rows + [header]).map { |r| r[i].length }.max }

      puts ids.map { |i| header[i].center(widths[i]) }.join(separator)
      puts '-' * (widths.inject(&:+) + separator.length * (header.length - 1))

      rows.each do |row|
        cells = ids.map do |i|
          row[i].send(alignment && alignment[i] || :ljust, widths[i])
        end

        puts cells.join(separator)
      end
    end
  end
end
