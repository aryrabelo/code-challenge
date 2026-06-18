# frozen_string_literal: true

require "json"

module SerpapiCodeChallenge
  # Tiny CLI / programmatic entrypoint, mirroring the ergonomics of the serpapi
  # gem (give it a source, get structured results back). It parses a local SERP
  # file, or renders a live URL through BrowserFetcher (headless Chrome), and
  # prints the artworks as the SerpApi-style {"artworks": [...]} JSON envelope.
  #
  #   extract path/to/serp.html
  #   extract --browser "https://www.google.com/search?q=Van+Gogh+paintings&hl=en"
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
      else
        path = @argv.find { |arg| !arg.start_with?("--") }
        raise ArgumentError, "usage: extract <file.html> | --browser <url>" if path.nil?

        File.read(path)
      end
    end

    def value_after(idx)
      @argv[idx + 1] or raise ArgumentError, "missing value after #{@argv[idx]}"
    end
  end
end
