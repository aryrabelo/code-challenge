# frozen_string_literal: true

require "serpapi_code_challenge"
require "tmpdir"

# The rate guard is the safeguard that prevents hammering Google. Tests drive a
# fake clock and a temp state file so they are fast and deterministic.
RSpec.describe SerpapiCodeChallenge::RateGuard do
  around do |example|
    Dir.mktmpdir { |dir| @state = File.join(dir, "throttle.json"); example.run }
  end

  def guard(now:, min_interval: 30, max_per_hour: 30)
    SerpapiCodeChallenge::RateGuard.new(min_interval: min_interval, max_per_hour: max_per_hour,
                  state_path: @state, clock: -> { now })
  end

  it "allows the first fetch" do
    expect { guard(now: 1000).check! }.not_to raise_error
  end

  it "raises TooFrequent on a second fetch within the cooldown" do
    guard(now: 1000).check!
    expect { guard(now: 1010).check! }.to raise_error(SerpapiCodeChallenge::RateGuard::TooFrequent, /interval/)
  end

  it "allows again once the minimum interval has elapsed" do
    guard(now: 1000).check!
    expect { guard(now: 1031).check! }.not_to raise_error
  end

  it "persists timestamps across instances (throttle survives a new process)" do
    guard(now: 1000).check!
    # a brand-new instance reading the same state file still sees the recent fetch
    expect { guard(now: 1005).check! }.to raise_error(SerpapiCodeChallenge::RateGuard::TooFrequent)
  end

  it "enforces a max-per-hour ceiling" do
    base = 100_000
    5.times { |i| guard(now: base + i * 40, max_per_hour: 5).check! } # 5 spaced fetches
    expect { guard(now: base + 5 * 40, max_per_hour: 5).check! }
      .to raise_error(SerpapiCodeChallenge::RateGuard::TooFrequent, /per hour/)
  end

  it "does not throttle with wait: false vs the NullGuard no-op" do
    SerpapiCodeChallenge::RateGuard.null.check!
    expect { SerpapiCodeChallenge::RateGuard.null.check! }.not_to raise_error
  end
end
