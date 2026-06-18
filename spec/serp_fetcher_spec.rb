# frozen_string_literal: true

require "support/vcr"
require "serp_fetcher"

# The challenge core needs NO network. SerpapiCodeChallenge::SerpFetcher exists only to acquire the
# *extra* carousel test pages — and every test of it replays a recorded VCR
# cassette, so the suite never hits Google live. This is the test-side half of
# the anti-blocking strategy.
RSpec.describe SerpapiCodeChallenge::SerpFetcher do
  it "presents a realistic browser User-Agent to lower the block profile" do
    expect(SerpapiCodeChallenge::SerpFetcher::DEFAULT_HEADERS["User-Agent"]).to match(%r{Mozilla/5\.0})
    expect(SerpapiCodeChallenge::SerpFetcher::DEFAULT_HEADERS).to include("Accept-Language")
  end

  it "fetches SERP html through a recorded cassette without hitting Google live" do
    VCR.use_cassette("serp_fetcher/picasso_paintings") do
      body = SerpapiCodeChallenge::SerpFetcher.get("https://www.google.com/search?q=Pablo+Picasso+paintings&hl=en&gl=us")
      expect(body).to include("data-attrid")
    end
  end
end
