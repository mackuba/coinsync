module CoinSync
  module Utils
    def self.lazy_require(source, name)
      begin
        require(name)
      rescue LoadError
        gem = name.split('/').first
        puts "#{source.class}: gem '#{gem}' is not installed"
        exit 1
      end
    end
  end
end
