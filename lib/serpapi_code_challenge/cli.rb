# frozen_string_literal: true

require "json"

module SerpapiCodeChallenge
  # Tiny CLI / programmatic entrypoint, mirroring the ergonomics of the serpapi
  # gem (give it a saved SERP file, get structured results back). It parses the
  # file and prints the artworks as the SerpApi-style {"artworks": [...]} JSON.
  #
  #   extract path/to/serp.html
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
      path = @argv.find { |arg| !arg.start_with?("--") }
      raise ArgumentError, "usage: extract <file.html>" if path.nil?

      File.read(path)
    end
  end
end
