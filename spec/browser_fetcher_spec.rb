# frozen_string_literal: true

require "serpapi_code_challenge"

# SerpapiCodeChallenge::BrowserFetcher is the in-repo, cmux-independent way to RENDER a Google SERP
# (headless Chrome via Ferrum). The live render is gated by Chrome availability
# and Google's anti-bot wall, so it is a skipped :browser integration test; the
# config/error behaviour is unit-tested here.
RSpec.describe SerpapiCodeChallenge::BrowserFetcher do
  it "auto-detects a Chrome binary (executable) or returns nil" do
    path = described_class.new.chrome_path
    expect(path).to be_nil.or satisfy { |p| File.executable?(p) }
  end

  it "honors an explicit CHROME_PATH / browser_path over auto-detection" do
    expect(described_class.new(browser_path: "/custom/chrome").chrome_path).to eq("/custom/chrome")
  end

  it "parses a host:port proxy and a full proxy URL" do
    expect(described_class.new(proxy: "10.0.0.1:8080").proxy).to eq(host: "10.0.0.1", port: 8080)
    expect(described_class.new(proxy: "http://user:pass@vpn.example:3128").proxy)
      .to include(host: "vpn.example", port: 3128, user: "user", password: "pass")
  end

  it "refuses to fetch when REQUIRE_VPN is set but no proxy is configured" do
    fetcher = described_class.new(browser_path: "/x", proxy: nil, require_vpn: true)
    expect { fetcher.get("https://www.google.com/search?q=x", timeout: 2) }
      .to raise_error(SerpapiCodeChallenge::BrowserFetcher::VpnRequiredError)
  end

  it "raises a typed BrowserError when the Chrome binary cannot launch" do
    fetcher = described_class.new(browser_path: "/no/such/chrome/binary")
    expect { fetcher.get("https://www.google.com/search?q=x", timeout: 3) }
      .to raise_error(SerpapiCodeChallenge::BrowserFetcher::BrowserError)
  end

  it "renders a live Google SERP into a parseable carousel", :browser do
    skip "set BROWSER_TESTS=1 (needs Chrome; live Google may be gated)" unless ENV["BROWSER_TESTS"]
    html = described_class.get("https://www.google.com/search?q=Claude+Monet+paintings&hl=en&gl=us")
    expect(SerpapiCodeChallenge::CarouselParser.new(html).artworks).not_to be_empty
  end
end
