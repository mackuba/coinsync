module CoinSync
  class SourceFilter
    def parse_command_line_args(arguments)
      selected = arguments.select { |a| !a.start_with?('^') }
      except = (arguments - selected).map { |a| a.gsub(/^\^/, '') }

      [selected, except]
    end
  end
end 
