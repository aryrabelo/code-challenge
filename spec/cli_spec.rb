# frozen_string_literal: true

require "serpapi_code_challenge"
require "support/vcr"
require "stringio"

# The CLI is the SerpApi-style entrypoint: parse a local SERP file, OR fetch a
# URL through SerpFetcher — which the suite replays from a VCR cassette, so the
# fetch path is exercised end-to-end without ever hitting Google live.
RSpec.describe SerpapiCodeChallenge::CLI do
  def run(*argv)
    out = StringIO.new
    status = described_class.run(argv, out: out)
    [status, out.string]
  end

  it "parses a local SERP file and prints the {\"artworks\": [...]} JSON envelope" do
    status, output = run(challenge_fixture("van-gogh-paintings.html"))
    data = JSON.parse(output)
    expect(status).to eq(0)
    expect(data.keys).to eq(["artworks"])
    expect(data["artworks"].length).to eq(47)
    expect(data["artworks"].first).to include(
      "name" => "The Starry Night",
      "link" => a_string_starting_with("https://www.google.com/search"),
    )
  end

  it "fetches a URL through SerpFetcher + VCR (never hitting Google live) and parses it" do
    out = StringIO.new
    VCR.use_cassette("serp_fetcher/picasso_paintings") do
      described_class.run(
        ["--url", "https://www.google.com/search?q=Pablo+Picasso+paintings&hl=en&gl=us"],
        out: out,
      )
    end
    data = JSON.parse(out.string)
    expect(data["artworks"]).not_to be_empty
    expect(data["artworks"].first["name"]).to eq("Guernica")
  end
end
