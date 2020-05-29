module CoinSync
  class SourceFilter
    def self.from_command_line_args(arguments)
      select = nil
      exclude = nil
      after = nil

      arguments.each do |a|
        case a
        when /^\w/
          select ||= []
          select << a
        when /^\^/
          exclude ||= []
          exclude << a[1..-1]
        when /^\~\-/
          after ||= []
          after << a[2..-1]
        when /^\~/
          select ||= []
          select << a[1..-1]
          after ||= []
          after << a[1..-1]
        else
          raise "Unexpected source specifier: #{a}"
        end
      end

      self.new(select: select, after: after, exclude: exclude)
    end

    def initialize(select: nil, after: nil, exclude: nil)
      @select = select
      @after = after
      @exclude = exclude
    end

    def select_from(sources)
      all = sources.keys

      selected = if !@select && !@after
        all
      elsif @select
        @select.each do |key|
          raise "Source not found in the config file: '#{key}'" unless all.include?(key)
        end

        @select
      else
        []
      end

      if @after
        @after.each do |key|
          index = all.index(key)
          raise "Source not found in the config file: '#{key}'" if index.nil?

          selected |= all[(index+1)..-1]
        end
      end

      if @exclude
        @exclude.each do |key|
          raise "Source not found in the config file: '#{key}'" unless all.include?(key)
          selected.delete(key)
        end
      end

      Hash[selected.sort.map { |key| [key, sources[key]] }]
    end
  end
end 
