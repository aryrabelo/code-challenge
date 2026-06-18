# frozen_string_literal: true

require "json"

module SerpapiCodeChallenge
  # Tiny CLI / programmatic entrypoint, mirroring the ergonomics of the serpapi
  # gem (give it a source, get structured results back). It parses a local SERP
  # file, or fetches a URL through SerpFetcher, and prints the artworks as the
  # SerpApi-style {"artworks": [...]} JSON envelope.
  #
  #   extract path/to/serp.html
  #   extract --url "https://www.google.com/search?q=Van+Gogh+paintings&hl=en"
  #
  # The fetch path goes through SerpFetcher, which the test suite replays from a
  # VCR cassette — so the network is recorded once and never hit live again.
  class CLI
    def self.run(argv, out: $stdout)
      new(argv).run(out)
    end

    def initialize(argv)
      @argv = Array(argv)
    end

    def run(out = $stdout)
      out.puts JSON.pretty_generate(CarouselParser.new(load_html).to_h)
      0
    end

    private

    def load_html
      if (idx = @argv.index("--browser"))
        BrowserFetcher.get(value_after(idx))   # headless-Chrome render (JS carousel)
      elsif (idx = @argv.index("--url"))
        SerpFetcher.get(value_after(idx))      # plain HTTP (no JS)
      else
        path = @argv.find { |arg| !arg.start_with?("--") }
        raise ArgumentError, "usage: extract <file.html> | --url <url> | --browser <url>" if path.nil?

        File.read(path)
      end
    end

    def value_after(idx)
      @argv[idx + 1] or raise ArgumentError, "missing value after #{@argv[idx]}"
    end
  end
end
