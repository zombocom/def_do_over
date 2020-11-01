# DidYouDo

Have you ever written some code and forgotten a piece of syntax, such as a missing `do` only to have Ruby give you an unhelpful error message:

```
1 def upcase_all(array)
2   array.map |x|
3    x.upcase
4  end
5 end
```

If you try to require or run this you get this message:

```
scratch.rb:6: syntax error, unexpected `end', expecting end-of-input
```


Experienced devs know they can backtrack to see if they forgot a `do`, a `def`, a `rescue` or some other syntax but it takes a long time to search through the whole file. Inexperienced devs who are new to this error are often baffled by this message. What if there was a better way?

Introducing `did_you_syntax_error`, a gem for helping to narrow down the search. Running it on the code above will narrow down our search:

```
DidYouSyntaxError: You've got missing or malformed syntax, such as a missing `do`
we've tried to narrow down the search. Start by looking at these lines:

2  array.map |x|
3    # ...
4  end
```

While this trivial example isn't very exciting, if the syntax error occurs in a file with hundreds or thousands of lines it can be very time consuming to track.

## Theories

- Invalid code with a syntax error is composed of smaller pieces of code that are either valid or invalid.
- If two pieces of code can be parsed, then they cannot create a syntax error when concatenated
- Removing a smaller piece of valid code from a larger file with a syntax error will not remove the syntax error

If these are all true then we can reduce the effective search space of some syntax errors such as "unexpected end" so that developers spend less time hunting for their syntax mistakes.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'did_you_do'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install did_you_do

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/did_you_do. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/did_you_do/blob/master/CODE_OF_CONDUCT.md).


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the DidYouDo project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/did_you_do/blob/master/CODE_OF_CONDUCT.md).
