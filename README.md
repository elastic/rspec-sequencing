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

Here is a real example from the Logstash file input plugin tests. Here we use Sequencing to let files age and other elapsed time mechanisms.
```ruby
    context "when ignore_older is less than close_older and all files are not expired" do
      let(:opts) { super.merge(:ignore_older => 1, :close_older => 1.1) }
      let(:suffix) { "N" }
      let(:actions) do
        RSpec::Sequencing
          .run_after(0.1, "file created") do
            File.open(file_path, "wb") { |file|  file.write("line1\nline2\n") }
          end
          .then("start watching before file age reaches ignore_older") do
            tailing.watch_this(watch_dir)
          end
          .then("wait for lines") do
            wait(1.2).for{listener1.calls}.to eq([:open, :accept, :accept, :timed_out])
          end
          .then("quit after allowing time to close the file") do
            tailing.quit
          end
      end

      it "reads lines normally" do
        actions.activate
        # subscribe is a blocking operation until tailing.quit is called on the sequence threads
        # and that last step is dependent on the wait(1.2).for rspec expectation to succeed. 
        tailing.subscribe(observer)
        actions.assert_no_errors # if the rspec `wait` call times out then this raises the RSpec failed assertion exception.
        expect(listener1.lines).to eq(["line1", "line2"])
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
  
 # use `activate` or `activate_quietly`, when defining a sequence in a `let` block,
 #   to get RSpec to instantiate the sequence.
  activate # this will print 'sequence activated' to the RSpec output_stream
  activate_quietly # this will print nothing to the RSpec output_stream
  value # this will block until the value from the last step is available
```
#### Note:
The description is optional, however by adding a description you document
the action in the code and the spec output. The description is printed after the delay and before the block is executed - use present tense, e.g. "Creating file" 

This library is multithreaded and uses the `concurrent-ruby` Dataflow feature.
Dataflow will absorb any exceptions and cause the dataflow to be rejected with the `reason` set to the Exception.
In this case, use the `assert_no_errors` method - this will re-raise the first exception it finds.

#### Note:
- The sequence executes in different threads from the main RSpec thread. You will need to wait for the sequence value (see this library's specs) otherwise the test will end before the sequence ends and any expectations based on side effects of the sequence will not be met. However, if you are testing scenarios where the main RSpec thread is blocked in some way, e.g. a subscribe loop, then one, usually the last, task should act to unblock the RSpec main thread. In this case you should not wait on the sequence value.
- The system that you are testing needs to be thread safe.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/elastic/rspec-sequencing.

