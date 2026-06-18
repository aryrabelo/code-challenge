#!/usr/bin/env ruby
# frozen_string_literal: true

# Capture live Google SERPs via SerpapiCodeChallenge::BrowserFetcher (Ferrum headless render) and record
# each as a VCR cassette for the multi-query parser tests. Run deliberately:
#
#   CHROME_PATH="/path/to/chrome" mise exec -- ruby script/capture_serps.rb
#
# Cassettes are committed; the test suite replays them and never hits Google.
require "uri"
require "yaml"
require "fileutils"
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "serpapi_code_challenge"

SerpapiCodeChallenge::RateGuard.default = SerpapiCodeChallenge::RateGuard.null # deliberate capture: we self-pace with sleeps

# Artist "<name> paintings" queries: the works carousel renders early and parses
# reliably. (Movie/album carousels render lower or are gated, so they are not used
# as deterministic fixtures — see GOAL.md backlog.)
# NOTE: Google starts serving consent/blocked pages after a couple of rapid
# automated hits even with stealth + spacing (that is the whole point of the rate
# guard). Keep this list short and bump the sleep if you add more.
QUERIES = [
  { slug: "picasso_paintings",  q: "Pablo Picasso paintings" },
  { slug: "da_vinci_paintings", q: "Leonardo da Vinci paintings" },
].freeze

DIR = File.expand_path("../spec/fixtures/cassettes/serp", __dir__)
FileUtils.mkdir_p(DIR)

QUERIES.each_with_index do |item, i|
  url = "https://www.google.com/search?q=#{URI.encode_www_form_component(item[:q])}&hl=en&gl=us&num=20"
  print "#{item[:slug]}: "
  html = SerpapiCodeChallenge::BrowserFetcher.get(url, timeout: 30)
  body = html.byteslice(0, [html.bytesize, 800_000].min)
  arts = SerpapiCodeChallenge::CarouselParser.new(body).artworks
  puts "#{html.bytesize}b -> #{body.bytesize}b | items=#{arts.length} | first=#{arts.first&.dig(:name).inspect}"
  puts "   url=#{url}"

  cassette = {
    "http_interactions" => [{
      "request" => { "method" => "get", "uri" => url,
                     "body" => { "encoding" => "US-ASCII", "string" => "" }, "headers" => {} },
      "response" => { "status" => { "code" => 200, "message" => "OK" },
                      "headers" => { "Content-Type" => ["text/html; charset=UTF-8"] },
                      "body" => { "encoding" => "UTF-8", "string" => body }, "http_version" => "1.1" },
      "recorded_at" => "Wed, 18 Jun 2026 00:00:00 GMT" }],
    "recorded_with" => "SerpapiCodeChallenge::BrowserFetcher (Ferrum headless render) captured into a VCR cassette",
  }
  File.write(File.join(DIR, "#{item[:slug]}.yml"), cassette.to_yaml)
  sleep 10 unless i == QUERIES.length - 1 # polite spacing between live hits
end
