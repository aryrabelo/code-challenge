# frozen_string_literal: true

require "serpapi_code_challenge"

RSpec.describe SerpapiCodeChallenge::CarouselParser do
  let(:expected) do
    JSON.parse(File.read(challenge_fixture("expected-array.json")))["artworks"]
  end

  # JSON round-trip turns the extractor's symbol keys into strings so the result
  # can be compared directly against the official oracle file.
  let(:artworks) do
    raw = described_class.from_file(challenge_fixture("van-gogh-paintings.html")).artworks
    JSON.parse(raw.to_json)
  end

  it "extracts every artwork in the carousel" do
    expect(artworks.length).to eq(47)
  end

  it "reproduces the official expected array exactly" do
    expect(artworks).to eq(expected)
  end

  it "returns an absolute google link for every item" do
    expect(artworks.map { |a| a["link"] }).to all(start_with("https://www.google.com/search"))
  end

  it "captures a thumbnail (inline data-uri or gstatic url) for every item" do
    expect(artworks.map { |a| a["image"] }).to all(match(%r{\A(?:data:image/|https://)}))
  end

  it "fully decodes inline base64 thumbnails with no leftover JS escapes" do
    inline = artworks.map { |a| a["image"] }.select { |i| i.start_with?("data:image") }
    expect(inline).not_to be_empty
    expect(inline).to all(satisfy { |i| !i.include?('\\x') })
  end

  it "omits the extensions key when an item has no date" do
    sunflowers = artworks.find { |a| a["name"] == "Sunflowers" }
    expect(sunflowers).not_to have_key("extensions")
  end

  it "wraps a present date in a one-element array" do
    starry = artworks.find { |a| a["name"] == "The Starry Night" }
    expect(starry["extensions"]).to eq(["1889"])
  end

  describe "generalization to other carousel layouts" do
    pages = Dir[File.join(ROOT, "spec", "fixtures", "pages", "*.html")]

    if pages.empty?
      it "has extra carousel fixtures to test against" do
        skip "no extra fixtures yet — fetch real SERP pages via cmux into spec/fixtures/pages/"
      end
    else
      pages.each do |path|
        it "extracts a non-empty carousel from #{File.basename(path)}" do
          items = described_class.from_file(path).artworks
          expect(items).not_to be_empty
          expect(items).to all(include(:name, :link))
        end
      end
    end
  end
end
