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

## Key principles

- Syntactiacally valid code does not mean "valid" code, it just means no syntax rules were violated. For our purposes we don't care if a method is defined, or if a variable is missing, the parser will detect those on its own. We only care about syntax errors.

## Theories

- Invalid code with a syntax error is composed of smaller pieces of code that are either valid or invalid.
- If two pieces of code can be parsed, then they cannot create a syntax error when concatenated
- Removing a smaller piece of valid code from a larger file with a syntax error will not remove the syntax error

If these are all true then we can reduce the effective search space of some syntax errors such as "unexpected end" so that developers spend less time hunting for their syntax mistakes.

- Invalid code can be wrapped in valid code, these can be verified independently:

```ruby
def foo
  @array.each |x|
  end
end
```

This whole thing could be considered a syntax error, but this code is valid:

```ruby
def foo
  # ...
end
```

If possible we want to isolate to the smallest set of code that is invalid.

- If a block of code with a syntax error is parsable after removing pieces of the code, than those pieces removed contain a syntax errror.

## Problems

Finding "possible code chunks" is a problem. We cannot rely on a parser to do this for us, since a parser relies on syntax rules being followed and our document has a syntax error.

Since this is inherently a search problem we could attempt to piece together parsable code character by character, storing when we see a change in state (from parsable to unparsable) then use these state changes later to determine if removing a chunk (or chunks) of code would make our program valid (thereby indicating they contained a syntax error). Alternatively you could consider randomly deleting chunks of code.

## Indentation informed search

Instead, if we assume that formatting is "reasonable" then we can use indentation to guide, but not limit, our search.

Our goal is to maximize the chance that a chunk of code is valid, if it is, then we can remove it from the search space. Conversely we also want to find the smallest chunk of code that is invlalid. To aid both of these we should look for smaller code chunks. We can start looking at the point of most indentation.

Consider this code:

```ruby
describe "this code" do
  def foo
    begin
      @array.each do |x|
      end
    rescue => e
      Foo.raise(e)
    end
  end

  def bar
    wrap_error
      Bar.call
    end
  end
end
```

The first line with the most indentation is:

```
      @array.each do |x|
```

There are no guarantees that a single line must be valid in Ruby, we must see if there's a matching end for this line, so we must search up and down. We can see that indentation changes and we end up with:


```
      @array.each do |x|
      end
```

This is valid syntax, so we know the error is not there. Remove it and keep looking


```ruby
describe "this code" do
  def foo
    begin
    rescue => e
      Foo.raise(e)
    end
  end

  def bar
    wrap_error
      Bar.call
    end
  end
end
```

Before moving on to the next indentation level, we see that there's another piece of code with the same indentation:

```ruby
      Foo.raise(e)
```

This parses, Same with

```
      Bar.call
```


This parses, so it's not our syntax error. Keep looking:


```
describe "this code" do
  def foo
    begin
    rescue => e
    end
  end

  def bar
    wrap_error
    end
  end
end
```

Now we've finished searching all areas with that indentation level. We can move on to the next, where `begin` starts. We search up and down and stop when indentation changes and end up with this:

```
    begin
    rescue => e
    end
```

This is valid. So we are left here:


```
describe "this code" do
  def foo
  end

  def bar
    wrap_error
    end
  end
end
```

Before moving on to `def foo` we first check:

```
  wrap_error
  end
```

This is not valid, this is a good candidate for our invalid code. but we don't know for sure that `wrap_error` is missing a `do`. Let's expand our search by one indentation level:

```
  def bar
    wrap_error
    end
  end
```

This whole thing errors with an unexpected end. We can theorize that we need to capture more code to generate valid syntax or alternatively that the invalid syntax is a subset of this code. To check we can try to see if removing any code makes this codeblock go from invalid to valid. We again use indentation to inform this decision and check just the smallest indented lines:

```
  def bar


  end
```

These parse. According to our theorms if we have code that when removed generates syntatically correct code, then we likely have code with a syntax error in it. At this point, its very likely our prior identified code has a syntax error. So we can mark it as potentially invalid and continue our search without it:


```
describe "this code" do
  def foo
  end

  # valid   def bar
  # invalid   wrap_error
  # invalid   end
  # valid   end
end
```

We could continue the search (which would begin with `def foo`) as there may be another syntax error in our document. If we did this we would see that the algorithm would tell us to look only at these two lines which is exactly where we're missing a `do`.

## Unknowns

Since coders do not always correctly indent their lines, it's unknown how valid this indentation based search is under "real world" conditions. The worst thing that could happen is that we declare a line with a syntax error to be valid. We always want to be greedy with what we show the user, as if we remove an invalid line from the error output, it's less likely a dev will look there themself. Even if we show "too much" to the user, it's no different than today where the search space is limited only to a file.

Is there an alternate way to "chunk" files for this guess and check? Sure! Let's find the edge cases where this fails to help inform us.


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
