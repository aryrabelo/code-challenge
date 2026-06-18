# frozen_string_literal: true

require "json"
require "fileutils"

# Safeguard against hitting Google too frequently. Persists fetch timestamps to a
# small state file so the throttle holds ACROSS processes and test runs — not just
# within one. By default it RAISES when called inside the cooldown (a hard
# guarantee); with `wait: true` it sleeps until the next slot is free instead.
#
# Live fetchers (SerpFetcher, BrowserFetcher) call RateGuard.default.check! before
# touching the network. Tests swap in RateGuard::NullGuard so replayed fetches are
# never throttled.
module SerpapiCodeChallenge; end

class SerpapiCodeChallenge::RateGuard
  class TooFrequent < StandardError; end

  DEFAULT_STATE = File.join(
    ENV.fetch("XDG_STATE_HOME", File.join(Dir.home, ".local", "state")),
    "serpapi_code_challenge", "fetch-throttle.json"
  )

  class << self
    attr_writer :default

    def default
      @default ||= new
    end

    def null
      NullGuard.new
    end
  end

  def initialize(min_interval: 30, max_per_hour: 30, state_path: DEFAULT_STATE, clock: -> { Time.now.to_f })
    @min_interval = min_interval
    @max_per_hour = max_per_hour
    @state_path = state_path
    @clock = clock
  end

  # Record a fetch if one is allowed right now; otherwise raise TooFrequent (or,
  # with wait: true, sleep until allowed). Returns the recorded timestamp.
  def check!(label: "google", wait: false)
    times = load_times
    now = @clock.call

    if (last = times.max) && (gap = now - last) < @min_interval
      raise TooFrequent, cooldown_message(label, gap) unless wait

      sleep(@min_interval - gap)
      now = @clock.call
      times = load_times
    end

    recent = times.count { |t| now - t < 3600 }
    raise TooFrequent, "rate guard: max #{@max_per_hour} fetches per hour reached (#{label})" if recent >= @max_per_hour

    record(times, now)
    now
  end

  # A drop-in guard that never throttles (used in tests).
  class NullGuard
    def check!(*) = nil
  end

  private

  def cooldown_message(label, gap)
    "rate guard: last #{label} fetch was #{gap.round(1)}s ago; minimum interval is " \
      "#{@min_interval}s (pass wait: true to throttle instead of raising)"
  end

  def load_times
    return [] unless File.exist?(@state_path)

    JSON.parse(File.read(@state_path)).fetch("times", []).map(&:to_f)
  rescue JSON::ParserError
    []
  end

  def record(times, now)
    keep = (times + [now]).select { |t| now - t < 3600 }.last(@max_per_hour * 2)
    FileUtils.mkdir_p(File.dirname(@state_path))
    File.write(@state_path, JSON.generate("times" => keep))
  end
end
