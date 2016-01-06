# Rspec::Sequencing

Define sequenced actions that simulate real-world scenarios, e.g write_file then 2 seconds later rename it

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

In your example group you can either define a sequence in a before block or a let block.  If you use a let block, then you should call the activate method on the sequence to get RSpec to create it, in a before block or in the example.

e.g. from the ruby-filewatch gem watch_spec.rb
```ruby
  context "when watching a directory with files" do
    let(:actions) do
      RSpec::Sequencing
        .run("create file") do
          File.open(file_path, "wb") { |file|  file.write("line1\nline2\n") }
        end
        .then_after(0.25, "start watching when directory has files") do
          subject.watch(File.join(directory, "*.log"))
        end
        .then_after(0.55, "quit after a short time") do
          subject.quit
        end
    end

    it "yields create_initial and one modify file events" do
      actions.activate
      subscribe_proc.call
      expect(results).to eq([[:create_initial, file_path], [:modify, file_path]])
    end
  end
```
and the spec output will be
```
FileWatch::Watch
  when watching a directory with files
    sequence activated
    subscribing
    create file
    start watching when directory has files
    quit after a short time
    yields create_initial and one modify file events
```

There are two class level constructional methods:
```ruby
  run(description = '', &block) # block runs without delay
  run_after(delay, description = '', &block) # block runs after delay seconds
```

and some instance methods:
```ruby
  then(description = '', &block) # when the previous action completed the block runs without delay
  then_after(delay, description = '', &block) # when the previous action completed the block runs after delay seconds
  dataflow(delay, description = '', inputs = [], &block)
  task(delay, &block)
```
Note that the description is optional, however by adding a description you document the action in the code and the spec output.

run

You are free to use the dataflow or task methods if you need unchained dataflows or tasks.

This library is multithreaded and uses the `concurrent-ruby` Dataflow and ScheduledTask mechanisms so you should set `Thread.abort_on_exception = true`
in your specs so any exceptions in your actions bubble up to spec execution.

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/elastic/rspec-sequencing.

