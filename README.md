# quick-rspec

`quick-rspec` runs only specs related to changed files

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'quick-rspec', require: false
```

Add this line at the end of your `config/application.rb`

```ruby
require 'quick-rspec'
```

And then execute:

    $ bundle

## Usage

Run whole test scope to collect statistics (to detect what everyone test checks):

```
rspec
```

Then when you made changes (when you have not committed files) run

```
rake quick_rspec
```

to run limited scope of tests.

```
rake quick_rspec DRY=yes
```

will show you information about specs that should be run to check your changes.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/desofto/quick-rspec


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

