# encoding: utf-8

require 'concurrent'

module RSpec
  class Sequencing
    def self.run(description = '', &block)
      run_after(0, description, &block)
    end

    def self.run_after(delay, description = '', &block)
      new.then_after(delay, description, &block)
    end

    attr_reader :flows

    def initialize
      @flows = []
    end

    def then_after(delay, description = '', &block)
      @flows << Concurrent.dataflow(*@flows) do
        sleep delay
        formatted_puts(description) unless description.empty?
        block.call
      end
      self
    end

    def then(description = '', &block)
      then_after(0, description, &block)
    end

    def activate_quietly
      # use this method if you define the sequencing in a let block so RSpec instantiates it
    end

    def activate
      # use this method if you define the sequencing in a let block so RSpec instantiates it
      formatted_puts "sequence activated"
    end

    def assert_no_errors
      # if you think you might get exceptions raised in any step the use this to get rspec to see them
      # the raised error gets set as the dataflow `reason`.
      value
      @flows.map do |flow|
        if flow.rejected?
          raise flow.reason
        end
        flow.value
      end
    end

    def value
      # this is a blocking operation
      @flows.last.value
    end

    private

    def formatted_puts(text)
      return if text.empty? || !doc_formatter?
      txt = RSpec.configuration.format_docstrings_block.call(text)
      RSpec.configuration.output_stream.puts "    #{txt}"
    end

    def doc_formatter?
      @doc_formatter ||= RSpec.configuration.formatters.first.is_a?(
        RSpec::Core::Formatters::DocumentationFormatter)
    end
  end
end
