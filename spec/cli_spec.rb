# frozen_string_literal: true

require "serpapi_code_challenge"
require "stringio"

# The CLI is the SerpApi-style entrypoint: parse a local SERP file and print the
# {"artworks": [...]} JSON envelope. (The live --browser path needs headless
# Chrome, so it is exercised under BROWSER_TESTS, not here.)
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
end
