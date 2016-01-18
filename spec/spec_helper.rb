# uses ruby-concurrent, so we can use Concurrent.monotonic_time
require "rspec_sequencing"

module RSpec
  class TimedTuple
    attr_reader :offset, :value
    def initialize(offset, value)
      @offset, @value = offset, value
    end

    def inspect
      "#{value} at #{offset}"
    end
  end

  class TimedTuples
    def initialize(start = monotonic_time)
      @start = start
      @results = Array.new
    end

    def add(value)
      @results << TimedTuple.new(monotonic_time - @start, value)
    end

    def results
      @results
    end

    def clear
      @results.clear
    end

    def monotonic_time
      Concurrent.monotonic_time
    end
  end
end
