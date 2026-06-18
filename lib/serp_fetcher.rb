# frozen_string_literal: true

require "net/http"
require "uri"
require "openssl"

# Fetches a Google SERP HTML page.
#
# IMPORTANT: the challenge core needs NO network — you parse the provided file.
# SerpFetcher exists only to acquire the *extra* carousel pages used as
# additional test fixtures, and in the test suite every call is replayed from a
# recorded VCR cassette (never a live Google hit). It sends a realistic browser
# User-Agent to keep a low block profile when a real fetch is genuinely needed.
module SerpapiCodeChallenge; end

class SerpapiCodeChallenge::SerpFetcher
  DEFAULT_HEADERS = {
    "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " \
                    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language" => "en-US,en;q=0.9",
  }.freeze

  # Only fetch Google over HTTPS — refuse arbitrary hosts so the CLI can't be
  # turned into an SSRF gadget (cloud metadata, loopback, RFC1918, etc.).
  # Strict: (www.)google.<tld>[.<cctld>] — rejects lookalikes such as
  # google.com.attacker.io while allowing google.com / google.co.uk / google.com.br.
  GOOGLE_HOST = /\A(www\.)?google(\.[a-z]{2,3}){1,2}\z/.freeze
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 15

  class FetchError < StandardError; end
  class UnsafeURLError < FetchError; end

  class HTTPError < FetchError
    attr_reader :code

    def initialize(code)
      @code = code
      super("unexpected HTTP status #{code}")
    end
  end

  def self.get(url, headers: {})
    uri = safe_uri(url)
    SerpapiCodeChallenge::RateGuard.default.check!(label: uri.host) # throttle: never hammer Google
    request = Net::HTTP::Get.new(uri)
    DEFAULT_HEADERS.merge(headers).each { |key, value| request[key] = value }

    response = transport(uri) { |http| http.request(request) }
    raise HTTPError, response.code unless response.is_a?(Net::HTTPSuccess)

    response.body
  end

  def self.safe_uri(url)
    uri = URI.parse(url)
    unless uri.is_a?(URI::HTTPS) && uri.host.to_s.match?(GOOGLE_HOST)
      raise UnsafeURLError, "refusing to fetch non-Google/non-HTTPS URL: #{url}"
    end

    uri
  rescue URI::InvalidURIError => e
    raise UnsafeURLError, "invalid URL: #{e.message}"
  end
  private_class_method :safe_uri

  def self.transport(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = READ_TIMEOUT
    http.start { |conn| yield conn }
  rescue SocketError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError,
         Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH => e
    raise FetchError, "fetch failed: #{e.class}: #{e.message}"
  end
  private_class_method :transport
end
