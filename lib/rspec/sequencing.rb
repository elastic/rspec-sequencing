require 'concurrent'

module RSpec
  class Sequencing
    def self.run(description = '', &block)
      run_after(0, description, &block)
    end

    def self.run_after(delay, description = '', &block)
      new.then_after(delay, description, &block)
    end

    def initialize
      @flow = nil
    end

    def then_after(delay, description = '', &block)
      @flow = dataflow(delay, description, [@flow], &block)
      self
    end

    def then(description, &block)
      then_after(0, description = '', &block)
    end

    def dataflow(delay, description = '', inputs = [], &block)
      Concurrent.dataflow(*inputs.compact) do
        task(delay, &block).execute.value
        formatted_puts(description) unless description.empty?
      end
    end

    def task(delay, &block)
      Concurrent::ScheduledTask.new(delay) do
        block.call
        true
      end
    end

    def activate
      # use this method if you define the sequencing in a let block
      # so RSpec runs it
      formatted_puts "sequence activated"
    end

    def value
      @flow.value
    end

    private

    def formatted_puts(text)
      txt = RSpec.configuration.format_docstrings_block.call(text)
      RSpec.configuration.output_stream.puts "    #{txt}"
    end
  end
end
