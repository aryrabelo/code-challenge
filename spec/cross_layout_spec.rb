# frozen_string_literal: true

require "serpapi_code_challenge"
require "support/vcr"

MONET_COUNT = 50
MONET_FIRST_NAME = "Impression, Sunrise"
PICASSO_COUNT = 45
PICASSO_FIRST_NAME = "Guernica"
TARSILA_COUNT = 42                  # Portuguese (pt-BR) locale page
TARSILA_FIRST_NAME = "Abaporu"

# Cross-layout / generalization correctness — the dimension the challenge most
# probes ("test against 2 other similar result pages... different layouts").
# These pin DETERMINISTIC facts, not just non-emptiness.
RSpec.describe SerpapiCodeChallenge::CarouselParser do
  def extract(name)
    described_class.from_file(File.join(ROOT, "spec", "fixtures", name)).artworks
  end

  describe "a non-painting carousel where the subtitle is not a year" do
    subject(:items) { extract("films-carousel.html") }

    it "extracts all three film items" do
      expect(items.length).to eq(3)
    end

    it "treats the subtitle (not a year) as extensions and never aliases a numeric title" do
      by_name = items.to_h { |i| [i[:name], i] }
      # numeric title must NOT be duplicated into extensions
      expect(by_name["1917"][:extensions]).to eq(["War film"])
      # a title containing digits must not leak into extensions either
      expect(by_name["Blade Runner 2049"][:extensions]).to eq(["Sci-fi film"])
      # a genuine year subtitle still works
      expect(by_name["Dunkirk"][:extensions]).to eq(["2017"])
    end

    it "yields no image for items whose thumbnail is not embedded in the page" do
      expect(items.map { |i| i[:image] }).to all(be_nil)
    end
  end

  describe "real fetched carousels (deterministic, pinned)" do
    it "extracts Monet's works carousel exactly" do
      items = extract("pages/monet-paintings.html")
      expect(items.length).to eq(MONET_COUNT)
      expect(items.first[:name]).to eq(MONET_FIRST_NAME)
      expect(items.first[:link]).to start_with("https://www.google.com/search")
    end

    # Picasso's page shares its parsed output with the serp_fetcher cassette, so
    # we replay that recorded SERP instead of storing the multi-MB raw page a
    # second time — same deterministic facts (45 / "Guernica"), one source of HTML.
    it "extracts Picasso's works carousel exactly" do
      items = VCR.use_cassette("serp_fetcher/picasso_paintings") do
        html = SerpapiCodeChallenge::SerpFetcher.get("https://www.google.com/search?q=Pablo+Picasso+paintings&hl=en&gl=us")
        described_class.new(html).artworks
      end
      expect(items.length).to eq(PICASSO_COUNT)
      expect(items.first[:name]).to eq(PICASSO_FIRST_NAME)
      expect(items.first[:link]).to start_with("https://www.google.com/search")
    end

    it "extracts a Portuguese (pt-BR) works carousel exactly" do
      items = extract("pages/tarsila-pinturas-ptbr.html")
      expect(items.length).to eq(TARSILA_COUNT)
      expect(items.first[:name]).to eq(TARSILA_FIRST_NAME)
      expect(items.first[:extensions]).to eq(["1928"])
    end

    # NOTE: the structural solution also pins a REAL non-:works carousel
    # (kc:/people/person:movies, Tarantino) whose cells use aria-labelledby +
    # sibling <img>. This ponytail parser deliberately does not target that
    # layout — it is outside the challenge's "same kind of carrousel" brief, and
    # supporting it is exactly the complexity the lazy version trades away.
  end

  describe "graceful handling and serialization" do
    it "returns an empty array for a page with no carousel" do
      expect(extract("no-carousel.html")).to eq([])
    end

    it "serializes to the SerpApi {\"artworks\": [...]} envelope with string keys" do
      envelope = described_class.from_file(challenge_fixture("van-gogh-paintings.html")).to_h
      expect(envelope.keys).to eq(["artworks"])
      expect(envelope["artworks"].length).to eq(47)
      expect(envelope["artworks"].first).to include("name" => "The Starry Night")
    end
  end
end
