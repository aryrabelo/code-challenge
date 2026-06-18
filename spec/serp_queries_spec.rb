# frozen_string_literal: true

require "serpapi_code_challenge"
require "support/vcr"

# Several different Google searches, captured LIVE via SerpapiCodeChallenge::BrowserFetcher (Ferrum
# headless render) and recorded as VCR cassettes (see script/capture_serps.rb).
# Each test replays its cassette through the HTTP fetcher and parses it — so the
# whole fetch -> parse path is exercised across queries, deterministically and
# offline (never hitting Google).
RSpec.describe "multi-query SERP fetch + parse (cassettes captured via Ferrum)" do
  CASES = [
    {
      slug: "picasso_paintings",
      url: "https://www.google.com/search?q=Pablo+Picasso+paintings&hl=en&gl=us&num=20",
      min: 30, first: "Guernica"
    },
    {
      slug: "da_vinci_paintings",
      url: "https://www.google.com/search?q=Leonardo+da+Vinci+paintings&hl=en&gl=us&num=20",
      min: 30, first: "Salvator Mundi"
    },
  ].freeze

  CASES.each do |c|
    it "fetches + parses the #{c[:slug]} carousel from its recorded cassette" do
      items = VCR.use_cassette("serp/#{c[:slug]}") do
        SerpapiCodeChallenge::CarouselParser.new(SerpapiCodeChallenge::SerpFetcher.get(c[:url])).artworks
      end

      expect(items.length).to be >= c[:min]
      expect(items.first[:name]).to eq(c[:first])
      expect(items).to all(include(:name, :link))
      expect(items.map { |i| i[:link] }).to all(start_with("https://www.google.com/search"))
    end
  end
end
