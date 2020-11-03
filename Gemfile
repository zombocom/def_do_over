require "objspace"; ObjectSpace.trace_object_allocations_start;
Kernel.send(:define_method, :sup) do |obj| ;
  puts "#{ ObjectSpace.allocation_sourcefile(obj) }:#{ ObjectSpace.allocation_sourceline(obj) }";
end

source "https://rubygems.org"

# Specify your gem's dependencies in did_you_do.gemspec
gemspec

gem "rake"
gem "rspec", "~> 3.0"
source "https://rubygems.org"

# Specify your gem's dependencies in did_you_do.gemspec
gemspec

gem "rake"
gem "rspec", "~> 3.0"
