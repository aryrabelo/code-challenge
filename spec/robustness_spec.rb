# frozen_string_literal: true

require "serpapi_code_challenge"
require "webmock/rspec"

# Hardening driven by the autoresearch:scenario edge-case sweep (12 dimensions).
RSpec.describe "robustness" do
  describe SerpapiCodeChallenge::CarouselParser do
    it "does not crash on invalid UTF-8 input" do
      # UTF-8-tagged bytes with an invalid sequence — what File.read yields for a
      # page with bad bytes; String#scan would otherwise raise here.
      bytes = "\xff\xfe<html><body></body></html>".dup.force_encoding("UTF-8")
      expect(bytes.valid_encoding?).to be(false)
      expect { SerpapiCodeChallenge::CarouselParser.new(bytes).artworks }.not_to raise_error
      expect(SerpapiCodeChallenge::CarouselParser.new(bytes).artworks).to eq([])
    end

    it "never emits javascript: links or unsafe (non-https/non-data:image) image schemes" do
      html = %(<div data-attrid="kc:/x/y:works"><a href="javascript:alert(1)//search?stick=z">) +
             %(<img data-src="//evil.tld/beacon.gif?leak=1"><div><div>Evil</div></div></a></div>)
      item = SerpapiCodeChallenge::CarouselParser.new(html).artworks.first
      expect(item[:name]).to eq("Evil")
      expect(item[:link]).to be_nil
      expect(item[:image]).to be_nil
    end
  end

  describe SerpapiCodeChallenge::SerpFetcher do
    let(:url) { "https://www.google.com/search?q=test" }

    it "raises a typed HTTPError on a non-success status" do
      stub_request(:get, /google\.com/).to_return(status: 403, body: "sorry")
      expect { SerpapiCodeChallenge::SerpFetcher.get(url) }.to raise_error(SerpapiCodeChallenge::SerpFetcher::HTTPError)
    end

    it "wraps transport failures in a typed FetchError" do
      stub_request(:get, /google\.com/).to_raise(SocketError.new("getaddrinfo failed"))
      expect { SerpapiCodeChallenge::SerpFetcher.get(url) }.to raise_error(SerpapiCodeChallenge::SerpFetcher::FetchError)
    end

    it "refuses non-HTTPS, non-Google, and internal hosts (SSRF guard)" do
      expect { SerpapiCodeChallenge::SerpFetcher.get("http://169.254.169.254/latest/meta-data/") }
        .to raise_error(SerpapiCodeChallenge::SerpFetcher::UnsafeURLError)
      expect { SerpapiCodeChallenge::SerpFetcher.get("https://evil.example.com/") }
        .to raise_error(SerpapiCodeChallenge::SerpFetcher::UnsafeURLError)
    end

    it "is not fooled by lookalike hosts that merely contain 'google.'" do
      ["https://google.com.attacker.io/", "https://www.google.com.evil.io/",
       "https://google.evil/", "https://notgoogle.com/"].each do |bad|
        expect { SerpapiCodeChallenge::SerpFetcher.get(bad) }.to raise_error(SerpapiCodeChallenge::SerpFetcher::UnsafeURLError), bad
      end
    end

    it "allows genuine google country domains" do
      stub_request(:get, /www\.google\.co\.uk/).to_return(status: 200, body: "ok")
      expect { SerpapiCodeChallenge::SerpFetcher.get("https://www.google.co.uk/search?q=x") }.not_to raise_error
    end
  end
end
