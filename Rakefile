# frozen_string_literal: true

require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

# `rake` runs the whole gate: correctness (incl. the 47/47 oracle spec) + the
# complexity/bug checks.
task default: %i[spec rubocop]
