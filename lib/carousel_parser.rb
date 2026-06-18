# frozen_string_literal: true

require "nokogiri"
require "json"

# Ponytail edition — the laziest parser that still reproduces the oracle.
#
# The challenge is "parse the provided local SERP file; no extra HTTP requests
# needed", so the whole fetch/VCR/anti-block/security stack of the structural
# solution simply does not need to exist here (ponytail rung 1: YAGNI). What's
# left is the irreducible core: a carousel item is a /search?...stick= anchor
# that carries a thumbnail; its name/date are the anchor's leaf-text divs; its
# image is the gstatic URL the page already gives, or the base64 the page embeds.
module SerpapiCodeChallenge; end

class SerpapiCodeChallenge::CarouselParser
  GOOGLE = "https://www.google.com"

  def self.from_file(path) = new(File.read(path))

  def initialize(html)
    @html = html.to_s.dup.force_encoding("UTF-8").scrub
    @doc = Nokogiri::HTML(@html) { |c| c.huge }
    # The 8 visible thumbnails are base64 in `var s='...';var ii=['<img id>']`
    # bootstrap scripts; the rest only reference a gstatic URL via data-src.
    @inline = @html.scan(%r{var s='(data:image/[^']*+)';var ii=\[([^\]]*+)\]})
                   .flat_map { |s, ii| ii.scan(/'([^']+)'/).map { |(id)| [id, unescape(s)] } }.to_h
  end

  def artworks
    @doc.css('a[href*="/search"][href*="stick="]').filter_map { |a| item(a) if a.at_css("img") }
  end

  def to_h = { "artworks" => artworks.map { |h| h.transform_keys(&:to_s) } }
  def to_json(*args) = JSON.generate(to_h, *args)

  private

  def item(anchor)
    texts = anchor.css("div")
                  .select { |d| d.children.any? && d.children.all?(&:text?) && !d.text.strip.empty? }
                  .map { |d| d.text.gsub(" ", " ").strip }
    return if texts.empty?

    art = { name: texts[0] }
    art[:extensions] = [texts[1]] if texts[1]
    art[:link] = GOOGLE + anchor["href"] if anchor["href"].start_with?("/") # lazy, not negligent
    art[:image] = image(anchor.at_css("img"))
    art
  end

  def image(img)
    src = img["data-src"].to_s
    src = @inline[img["id"]].to_s if src.empty?
    src if src.start_with?("https://", "data:image/") # only trust http(s)/raster data-URIs
  end

  def unescape(str)
    str.gsub(/\\x(\h\h)/) { $1.to_i(16).chr }.gsub(/\\u(\h{4})/) { [$1.to_i(16)].pack("U") }.gsub('\\/', "/")
  end
end
