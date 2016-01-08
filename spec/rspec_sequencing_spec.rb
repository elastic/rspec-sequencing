require_relative 'spec_helper'

describe RSpec::Sequencing do
  let(:timed_tuples)   { RSpec::TimedTuples.new }

  context "when building a sequence without delay times" do
    before do
      timed_tuples.clear
      RSpec::Sequencing.run("first") do
        timed_tuples.add("I")
      end
        .then("second") do
          timed_tuples.add("II")
        end
          .then("third") do
            timed_tuples.add("III")
          end
          .value
          # use value to make the before block wait for sequence value (Concurrent::Future)
          # or use rspec/wait or sleep N here or in the example group
    end

    it "the by-product of ordered async execution yields values" do
      values = timed_tuples.results.map{|tt| tt.value}
      expect(values).to eq(["I", "II", "III"])
    end
  end

  context "when building a sequence with delay times" do
    before do
      timed_tuples.clear
      RSpec::Sequencing.run_after(0.15, "executed first task") do
        timed_tuples.add("I")
      end
        .then_after(0.25, "executed second task") do
          timed_tuples.add("II")
        end
          .then_after(0.35, "executed third task") do
            timed_tuples.add("III")
          end
            .value
    end

    it "the by-product of ordered async execution shows a timeline" do
      task1 = timed_tuples.results[0]
      expect(task1.offset).to be_within(0.05).of(0.15)
      expect(task1.value).to eq("I")
      task2 = timed_tuples.results[1]
      expect(task2.offset).to be_within(0.05).of(0.15 + 0.25)
      expect(task2.value).to eq("II")
      task3 = timed_tuples.results[2]
      expect(task3.offset).to be_within(0.05).of(0.15 + 0.25 + 0.35)
      expect(task3.value).to eq("III")
    end
  end
end

__END__

The console output should look like this:

bundle exec rspec spec/rspec_sequencing_spec.rb

RSpec::Sequencing
  when building a sequence without delay times
    first
    second
    third
    the by-product of ordered async execution yields values
  when building a sequence with delay times
    executed first task
    executed second task
    executed third task
    the by-product of ordered async execution shows a timeline

Finished in 0.8 seconds (files took 0.402 seconds to load)
2 examples, 0 failures
