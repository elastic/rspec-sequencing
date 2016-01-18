# Rspec::Sequencing

Define sequenced actions that simulate real-world scenarios, e.g. write_file then 2 seconds later rename it or execute a sequence of actions on a http server

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rspec-sequencing'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rspec-sequencing

## Usage

Generally one would use this when you need to have a series of actions occur in way that reflects the real world in terms of being asynchronous, serial, and spread out over time especially when the library code you are testing has difficult to mock dependencies like sockets, files, servers or apis, i.e. integration testing.

Add `require "rspec_sequencing"` in your spec_helper.rb or equivalent.

### Example

Lets start with an abstract example. Imagine you want to fully test a Order Processing external api. Suppose you want to test the Product Return/Refund api call.
Assumptions:
- you have a client class that connects to the gateway.
- the client returns a response message from the api call.
- the order processing system uses background jobs to handle order changes
- necessary `let` variables for creds, order details and client etc. are available.

```ruby
  context "when refunding an order" do
    let(:results)  { Hash.new(NullObject.new) }

    it "returns-processing starts and a refund is pending" do
      RSpec::Sequencing
        .run("login") do
          results[:auth] = client.login(*creds)
        end
        .then("place order") do
          results[:new_order] = client.place_order(order_details)
        end
        .then_after(2, "pay for order") do #<-- wait for place order background job
          results[:pay_order] = client.pay_for_order(order_details)
        end
        .then_after(1, "ship order because we received payment") do
          results[:shipit] = client.ship_order(order_details)
        end
        .then_after(2, "refund order") do
          results[:refund] = client.refund_order(order_details)
        end
        .value # <-- we need to wait for the last action to complete

      expect(results[:auth]).to      eq("Welcome")
      expect(results[:new_order]).to eq("Order placed. Picking started")
      expect(results[:pay_order]).to eq("Payment received, thank you.")
      expect(results[:shipit]).to    eq("Order shipped")
      expect(results[:refund]).to    eq("Order returns processing started, you will receive a refund when we receive the goods back")
    end
  end
```
and the spec output will be
```
  when refunding an order
    login
    place order
    pay for order
    ship order because we received payment
    refund order
    returns-processing starts and a refund is pending
```

You might be tempted to think, I can just do:
```ruby
  context "when refunding an order" do
    it "returns-processing starts and a refund is pending" do
      message = client.login(*creds)
      expect(message).to eq("Welcome")

      message = client.place_order(order_details)
      expect(message).to eq("Order placed. Picking started")

      sleep 2
      message = client.pay_for_order(order_details)
      expect(message).to eq("Payment received, thank you.")

      sleep 1
      message = client.ship_order(order_details)
      expect(message).to eq("Order shipped")

      sleep 2
      message = client.refund_order(order_details)
      expect(message).to eq("Order returns processing started, you will receive a refund when we receive the goods back")
    end
  end
```
and you would be correct, for this contrived example.

Here is a real example from the ruby-file_watch library. Here we use Sequencing to let files age and other elapsed time mechanisms.
```ruby
describe FileWatch::Watch do
  before(:all) do
    @thread_abort = Thread.abort_on_exception
    Thread.abort_on_exception = true
  end

  after(:all) do
    Thread.abort_on_exception = @thread_abort
  end

  let(:directory) { Stud::Temporary.directory }
  let(:watch_dir) { File.join(directory, "*.log") }
  let(:file_path) { File.join(directory, "1.log") }
  let(:loggr)     { double("loggr", :debug? => true) }
  let(:results)   { [] }
  let(:stat_interval) { 0.1 }
  let(:discover_interval) { 4 }

  let(:subscribe_proc) do
    lambda do
      formatted_puts("subscribing")
      # subject subscribe does not return until subject.quit is called
      subject.subscribe(stat_interval, discover_interval) do |event, watched_file|
        results.push([event, watched_file.path])
      end
    end
  end

  subject { FileWatch::Watch.new(:logger => loggr) }

  before do
    allow(loggr).to receive(:debug)
  end
  after do
    FileUtils.rm_rf(directory)
  end

  context "when ignore older and close older expiry is enabled and after timeout the file is appended-to" do
    before do
      subject.ignore_older = 2
      subject.close_older = 2

      RSpec::Sequencing
        .run("create file") do
          File.open(file_path, "wb") { |file|  file.write("line1\nline2\n") }
        end
        .then_after(3.1, "start watching after the file ages more than two seconds") do
          subject.watch(watch_dir)
        end
        .then("append more lines to file when its 'ignored'") do
          File.open(file_path, "ab") { |file|  file.write("line3\nline4\n") }
        end
        .then_after(3.1, "quit after allowing time for the close mechanism (timeout)") do
          subject.quit #<--- this unblocks the subscribe loop
        end
    end

    it "yields unignore, modify then timeout file events" do
      subscribe_proc.call #<--- the rspec thread is in a forever loop until quit is called in another thread
      expect(results).to eq([[:unignore, file_path], [:modify, file_path], [:timeout, file_path]])
    end
  end
end
```

### API

There are two class level constructional methods:
```ruby
  run(description = '', &block) # block runs without delay
  run_after(delay, description = '', &block) # block runs after delay seconds
```

and some instance methods:
```ruby
  then(description = '', &block) # when the previous action completed the block runs without delay
  then_after(delay, description = '', &block) # when the previous action completed the block runs after delay seconds
```
Note that the description is optional, however by adding a description you document the action in the code and the spec output.

This library is multithreaded and uses the `concurrent-ruby` Dataflow and ScheduledTask mechanisms so you should set `Thread.abort_on_exception = true`
in your specs so any exceptions in your actions bubble up to spec execution.

### Please note:
- The sequence executes in different threads from the main RSpec thread. You will need to wait for the sequence value (see this library's specs) otherwise the test will end before the sequence ends and any expectations based on side effects of the sequence will not be met. However, if you are testing scenarios where the main RSpec thread is blocked in some way, e.g. a subscribe loop, then one, usually the last, task should act to unblock the RSpec main thread. In this case you should not wait on the sequence value.
- The system that you are testing needs to be thread safe.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/elastic/rspec-sequencing.

