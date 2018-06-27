# encoding: utf-8

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

  context "if a block does not raise an error, the sequence completes" do
    let(:actions) do
      RSpec::Sequencing.run("executed first task") do
        :starting
      end
      .then_after(0.25, "executed second task") do
        :and_then
      end
      .then_after(0.25, "executed third task") do
        :finally
      end
    end
    it "`assert_no_errors` will re-raise the error in the example group thread" do
      actions.activate_quietly
      expect{actions.assert_no_errors}.not_to raise_exception
      expect(actions.assert_no_errors).to eq([:starting, :and_then, :finally])
    end
  end

  context "if a block raises an error, the sequence completes" do
    context "when raising one error" do
      let(:actions) do
        RSpec::Sequencing.run("executed first task") do
          timed_tuples.add("I")
          :starting
        end
        .then_after(0.25, "executed second task") do
          raise "Ooops"
        end
        .then_after(0.25, "executed third task") do
          timed_tuples.add("II")
          :done
        end
      end
      it "`assert_no_errors` will re-raise the only error in the example group thread" do
        timed_tuples.clear
        actions.activate_quietly
        expect{actions.assert_no_errors}.to raise_exception("Ooops")
        expect(timed_tuples.results[1].value).to eq("II")
        expect(actions.value).to eq(:done)
      end
    end

    context "when raising two errors" do
      let(:actions) do
        RSpec::Sequencing.run("executed first task") do
          raise "Ooops X"
        end
        .then_after(0.25, "executed second task") do
          raise "Ooops Y"
        end
      end
      it "`assert_no_errors` will re-raise the first error in the example group thread" do
        actions.activate_quietly
        expect{actions.assert_no_errors}.to raise_exception("Ooops X")
      end
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
