module CoinSync
  class Balance
    attr_reader :currency, :available, :locked

    def initialize(currency, available: BigDecimal(0), locked: BigDecimal(0))
      @currency = currency
      @available = available
      @locked = locked
    end

    def +(balance)
      return Balance.new(
        @currency,
        available: @available + balance.available,
        locked: @locked + balance.locked
      )
    end
  end
end
