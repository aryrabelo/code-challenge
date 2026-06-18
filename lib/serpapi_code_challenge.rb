# frozen_string_literal: true

require_relative "serpapi_code_challenge/version"
require_relative "carousel_parser"
require_relative "serpapi_code_challenge/cli"

# Top-level namespace for the SerpApi "Extract Van Gogh Paintings" code challenge.
#
# The workhorse is CarouselParser, which parses a saved Google SERP HTML page
# and returns the knowledge-graph artworks carousel as structured data.
module SerpapiCodeChallenge
  def self.extract(html_or_path)
    if File.exist?(html_or_path)
      CarouselParser.from_file(html_or_path).artworks
    else
      CarouselParser.new(html_or_path).artworks
    end
  end
end
