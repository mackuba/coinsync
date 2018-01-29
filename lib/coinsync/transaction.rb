def parse_float(string)
  string.gsub(/,/, '.').to_f
end

def format_float(value, prec)
  sprintf("%.#{prec}f", value).gsub(/\./, ',')
end

class Transaction
  attr_accessor :lp, :source, :type, :date, :btc_amount, :price, :input

  def self.from_line(line)
    lp = line[0].to_i
    source = line[1]
    type = line[2]
    date = line[3]
    btc_amount = parse_float(line[4])
    price = parse_float(line[6])
    
    new(lp: lp, source: source, type: type, date: date, btc_amount: btc_amount, price: price)
  end

  def initialize(lp:, source:, type:, date:, btc_amount:, price:, input: nil, amount: nil)
    @lp = lp
    @source = source
    @type = type
    @date = date
    @btc_amount = btc_amount
    @price = price
    @input = input
    @amount = amount
  end

  def buy?
    type.downcase == "kup"
  end

  def to_line
    amount = @amount || @btc_amount

    data = [
      lp,
      source,
      type,
      date,
      format_float(amount, 8),
      format_float(amount * price, 4),
      format_float(price, 4)
    ]

    if input
      data += [
        input.lp,
        format_float(input.price, 4),
        format_float(amount * input.price, 4),
        format_float(amount * price, 4),
        format_float(amount * (price - input.price), 4)
      ]
    end

    data
  end
end
