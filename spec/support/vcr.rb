# frozen_string_literal: true

require "vcr"
require "webmock/rspec"

VCR.configure do |config|
  config.cassette_library_dir = File.join(ROOT, "spec", "fixtures", "cassettes")
  config.hook_into :webmock
  config.configure_rspec_metadata!
  # Replay only. Tests/CI must NEVER hit Google live: record a cassette once
  # locally, commit it, and replay forever. This is the test-side half of the
  # anti-blocking strategy (see GOAL.md).
  # Match on the query too, so each query's cassette replays only for that query
  # (otherwise every /search request would match the first cassette).
  config.default_cassette_options = {
    record: :none,
    match_requests_on: %i[method host path query],
  }
  config.allow_http_connections_when_no_cassette = false
end
