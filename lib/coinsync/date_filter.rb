require 'time'

class DateFilter
  attr_reader :date_since, :date_until

  def initialize(hash = {})
    if time = hash['since']
      @date_since = Time.parse(hash['since'])
    end

    if time = hash['until']
      if time.include?(':')
        @date_until = Time.parse(hash['until'])
      else
        # until last second of the day
        @date_until = (Date.parse(time) + 1).to_time - Float::MIN
      end
    end
  end

  def range_includes(transaction)
    return false if date_since && transaction.time < date_since
    return false if date_until && transaction.time > date_until
    true
  end
end
