require "bundler/setup"
require "did_you_do"
require "pathname"
require "tmpdir"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

def spec_dir
  Pathname(__dir__)
end

def root_dir
  spec_dir.join("..")
end

def lib_dir
  root_dir.join("lib")
end
