# frozen_string_literal: true

require "json"
require "nokogiri"

ROOT = File.expand_path("..", __dir__)
$LOAD_PATH.unshift File.join(ROOT, "lib")

module SpecPaths
  def challenge_fixture(name)
    File.join(ROOT, "files", name)
  end

  def page_fixture(name)
    File.join(ROOT, "spec", "fixtures", "pages", name)
  end
end

RSpec.configure do |config|
  config.include SpecPaths
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.order = :defined
end
