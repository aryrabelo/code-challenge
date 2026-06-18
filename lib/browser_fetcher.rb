# frozen_string_literal: true

require "uri"

# Programmatic, in-repo browser fetcher — the cmux-independent way to RENDER a
# Google SERP. The knowledge-graph carousel is injected by JavaScript, so a plain
# HTTP GET never sees it; BrowserFetcher drives a headless Chrome via Ferrum to
# run that JS and returns the rendered HTML.
#
# Chrome is a runtime prerequisite (like Ruby). Set CHROME_PATH, or it auto-detects
# common Chrome / Chromium / Brave / Playwright locations.
#
# Anti-block safeguards:
#   * every live render passes through SerpapiCodeChallenge::RateGuard.default (throttle), and
#   * an optional VPN/proxy (VPN_PROXY) routes the browser; with REQUIRE_VPN=1 it
#     refuses to fetch unless a proxy is configured, and #egress_ip asks the browser
#     itself what public IP it is leaving from (so you can confirm the VPN is live).
#
# Google serves a stripped/consent page to obvious automation (navigator.webdriver),
# so we undefine that flag and send a consent cookie + real User-Agent to load the
# real results — standard hygiene for a legitimate SERP fetch. This is best-effort;
# for deterministic tests, capture once and replay the committed cassette/fixture.
module SerpapiCodeChallenge; end

class SerpapiCodeChallenge::BrowserFetcher
  class BrowserError < StandardError; end
  class VpnRequiredError < BrowserError; end

  CONSENT_COOKIE = "CAESEwgDEgk0ODE3Nzk3MjQaAmVuIAEaBgiA_LyaBg"
  USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
               "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
  IP_ECHO = "https://api.ipify.org"
  CAROUSEL_READY = "a[href*='stick=']"
  STEALTH_JS = "Object.defineProperty(navigator, 'webdriver', { get: () => undefined });"

  CHROME_CANDIDATES = [
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
    "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser",
  ].freeze

  def self.get(url, timeout: 25, **opts)
    new(**opts).get(url, timeout: timeout)
  end

  def initialize(browser_path: ENV["CHROME_PATH"], proxy: ENV["VPN_PROXY"], require_vpn: ENV["REQUIRE_VPN"] == "1")
    @browser_path = browser_path || detect_chrome
    @proxy = parse_proxy(proxy)
    @require_vpn = require_vpn
  end

  attr_reader :proxy

  def chrome_path
    @browser_path
  end

  # Render +url+ in headless Chrome (waiting for the carousel) and return the HTML.
  def get(url, timeout: 25)
    ensure_vpn!
    SerpapiCodeChallenge::RateGuard.default.check!(label: "browser")
    with_browser(timeout) do |browser|
      browser.go_to(url)
      await_carousel(browser, timeout)
      browser.body
    end
  end

  # Ask the browser what public IP it is leaving from — proof the VPN/proxy is in
  # effect (compare against your real IP). Routes through the configured proxy.
  def egress_ip(timeout: 15)
    with_browser(timeout) do |browser|
      browser.go_to(IP_ECHO)
      settle(browser, timeout)
      browser.at_css("body")&.text.to_s.strip
    end
  end

  private

  def with_browser(timeout)
    require "ferrum"
    browser = build_browser(timeout)
    apply_stealth(browser)
    browser.cookies.set(name: "SOCS", value: CONSENT_COOKIE, domain: ".google.com", path: "/")
    yield browser
  rescue LoadError
    raise BrowserError, "the `ferrum` gem is required for --browser (gem install ferrum) plus a Chrome binary"
  rescue VpnRequiredError, SerpapiCodeChallenge::RateGuard::TooFrequent
    raise
  rescue StandardError => e
    raise BrowserError, "browser fetch failed: #{e.class}: #{e.message}"
  ensure
    browser&.quit
  end

  def ensure_vpn!
    return unless @require_vpn
    return unless @proxy.nil?

    raise VpnRequiredError,
          "REQUIRE_VPN is set but no VPN_PROXY is configured — refusing to fetch with the real IP"
  end

  def build_browser(timeout)
    options = {
      browser_path: @browser_path, headless: true, window_size: [1366, 900],
      timeout: timeout, process_timeout: timeout + 10, pending_connection_errors: false
    }
    options[:proxy] = @proxy if @proxy
    Ferrum::Browser.new(**options).tap do |browser|
      browser.headers.set("User-Agent" => USER_AGENT, "Accept-Language" => "en-US,en;q=0.9")
    end
  end

  # Undefine navigator.webdriver before any page script runs, so Google serves the
  # real JS-rendered results instead of a stripped/consent page.
  def apply_stealth(browser)
    browser.page.command("Page.addScriptToEvaluateOnNewDocument", source: STEALTH_JS)
  rescue StandardError
    nil
  end

  # Poll for the carousel anchors to appear (JS render), bounded by timeout.
  def await_carousel(browser, timeout)
    deadline = monotonic + timeout
    until monotonic >= deadline
      begin
        return if browser.at_css(CAROUSEL_READY)
      rescue StandardError
        # frame still navigating — keep waiting
      end
      sleep 0.5
    end
  end

  def settle(browser, timeout)
    browser.network.wait_for_idle(timeout: timeout)
  rescue StandardError
    nil
  end

  def monotonic
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  # Accept "host:port" or "scheme://user:pass@host:port"; nil when unset.
  def parse_proxy(value)
    return nil if value.nil? || value.to_s.empty?

    uri = URI.parse(value.match?(%r{\A\w+://}) ? value : "http://#{value}")
    { host: uri.host, port: uri.port, user: uri.user, password: uri.password }.compact
  rescue URI::InvalidURIError
    nil
  end

  def detect_chrome
    CHROME_CANDIDATES.find { |path| File.executable?(path) } ||
      Dir.glob(File.expand_path("~/Library/Caches/ms-playwright/chromium-*/chrome-mac-*/*.app/Contents/MacOS/*"))
         .reject { |path| path.include?("crashpad") }
         .find { |path| File.executable?(path) }
  end
end
