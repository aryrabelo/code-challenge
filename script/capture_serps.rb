#!/usr/bin/env ruby
# frozen_string_literal: true

# Capture live Google SERPs via SerpapiCodeChallenge::BrowserFetcher (Ferrum
# headless render) and save each as an HTML page fixture for the cross-layout
# parser tests. Run deliberately:
#
#   CHROME_PATH="/path/to/chrome" mise exec -- ruby script/capture_serps.rb
#
# The saved pages are committed and the suite parses them directly (no network).
# To add a new layout: append to QUERIES, run this, then pin its facts in
# spec/cross_layout_spec.rb.
require "uri"
require "fileutils"
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "serpapi_code_challenge"

SerpapiCodeChallenge::RateGuard.default = SerpapiCodeChallenge::RateGuard.null # deliberate capture: we self-pace with sleeps

# Artist "<name> paintings" queries render the works carousel early and reliably.
# NOTE: Google starts serving consent/blocked pages after a couple of rapid
# automated hits even with stealth + spacing (that is the whole point of the rate
# guard). Keep this list short and bump the sleep if you add more.
QUERIES = [
  { slug: "picasso-paintings",  q: "Pablo Picasso paintings" },
  { slug: "da-vinci-paintings", q: "Leonardo da Vinci paintings" },
].freeze

DIR = File.expand_path("../spec/fixtures/pages", __dir__)
FileUtils.mkdir_p(DIR)

QUERIES.each_with_index do |item, i|
  url = "https://www.google.com/search?q=#{URI.encode_www_form_component(item[:q])}&hl=en&gl=us&num=20"
  print "#{item[:slug]}: "
  html = SerpapiCodeChallenge::BrowserFetcher.get(url, timeout: 30)
  body = html.byteslice(0, [html.bytesize, 1_300_000].min) # cap size; the carousel renders early
  arts = SerpapiCodeChallenge::CarouselParser.new(body).artworks
  puts "#{html.bytesize}b -> #{body.bytesize}b | items=#{arts.length} | first=#{arts.first&.dig(:name).inspect}"

  File.write(File.join(DIR, "#{item[:slug]}.html"), body)
  sleep 10 unless i == QUERIES.length - 1 # polite spacing between live hits
end
