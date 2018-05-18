require 'cri'

# don't use colors in help
module Cri
  class StringFormatter
    def format_as_title(str, io)
      str.upcase.bold
    end

    def format_as_command(str, io)
      str
    end

    def format_as_option(str, io)
      str
    end
  end
end

# to allow ignoring unknown options
class Cri::OptionParser
  def run
    @running = true

    while running?
      # Get next item
      e = @unprocessed_arguments_and_options.shift
      break if e.nil?

      begin
        if e == '--'
          handle_dashdash(e)
        elsif e =~ /^--./ && !@no_more_options
          handle_dashdash_option(e)
        elsif e =~ /^-./ && !@no_more_options
          handle_dash_option(e)
        else
          add_argument(e)
        end
      rescue IllegalOptionError
        add_argument(e)
      end
    end

    add_defaults

    self
  ensure
    @running = false
  end
end
