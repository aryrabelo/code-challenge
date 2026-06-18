# frozen_string_literal: true

require "nokogiri"
require "json"

# One lean parser covering every carousel the suite pins: the Van Gogh oracle,
# the Monet/Picasso/Tarsila :works carousels, and the real non-:works films one.
module SerpapiCodeChallenge; end

class SerpapiCodeChallenge::CarouselParser
  GOOGLE = "https://www.google.com"
  ENTITY = %r{kc:/\w+/\w+:\w+}
  RASTER = %r{\Ahttps://|\Adata:image/(?:png|jpe?g|gif|webp);base64,}

  def self.from_file(path) = new(File.read(path))

  def initialize(html)
    @html = html.to_s.dup.force_encoding("UTF-8").scrub
    @doc = Nokogiri::HTML(@html) { |c| c.huge }                  # huge: don't truncate the DOM
    # Visible cells embed base64 thumbnails in `var s='…';var ii=['<img id>']`
    # scripts; the rest only reference a gstatic URL via data-src.
    @inline = @html.scan(%r{var s='(data:image/[^']*+)';var ii=\[([^\]]*+)\]})
                   .flat_map { |s, ii| ii.scan(/'([^']+)'/).map { |(id)| [id, unescape(s)] } }.to_h
  end

  def artworks
    container.css('a[href*="/search"][href*="stick="]').filter_map { |a| item(a) }
  end

  def to_h = { "artworks" => artworks.map { |h| h.transform_keys(&:to_s) } }
  def to_json(*args) = JSON.generate(to_h, *args)

  private

  # Scope to ONE carousel by its durable knowledge-graph data-attrid: the artist
  # works section, else any ":works", else the first entity carousel that holds
  # stick= anchors (a person's films/books); whole document as a last resort.
  def container
    @doc.at_css('[data-attrid="kc:/visual_art/visual_artist:works"]') ||
      @doc.css("[data-attrid]").find { |n| n["data-attrid"].to_s.end_with?(":works") } ||
      @doc.css("[data-attrid]").find { |n| n["data-attrid"].to_s.match?(ENTITY) && n.at_css('a[href*="stick="]') } ||
      @doc
  end

  def item(anchor)
    text_name, subtitle = labels(anchor)
    name = alt_name(anchor) || text_name
    return unless name

    art = { name: name }
    art[:extensions] = [subtitle] if subtitle
    art[:link] = GOOGLE + anchor["href"] if anchor["href"].start_with?("/")
    art[:image] = image(anchor)
    art
  end

  # Prefer the image's alt text — Google's screen-reader label for the cell, which
  # is the artwork title verbatim. It is semantic (independent of Google's rotating
  # div nesting), so it is the most durable name source; the structural leaf-text /
  # aria labels below are the fallback for cells whose <img> carries no alt (films).
  def alt_name(anchor)
    img = anchor.at_css("img") || cell_image(anchor)
    img && norm(img["alt"])
  end

  # Name + optional date: the anchor's inner leaf-text divs (paintings), or the
  # aria-labelledby spans an empty entity-carousel anchor points at (films).
  def labels(anchor)
    texts = anchor.css("div")
                  .select { |d| d.children.any? && d.children.all?(&:text?) && !d.text.strip.empty? }
                  .map { |d| clean(d) }
    return texts.first(2) if texts.first

    anchor["aria-labelledby"].to_s.split.first(2).map { |id| clean(@doc.at_css("##{id}")) }
  end

  # Thumbnail: inside the anchor (paintings) a gstatic data-src or embedded
  # base64; beside it (films) the data-URI in a sibling <img> src. Only https /
  # raster data-URIs are emitted (no svg/js beacons).
  def image(anchor)
    inner = anchor.at_css("img")
    img = inner || cell_image(anchor)
    return unless img

    keys = inner ? %w[data-src] : %w[src data-src]
    src = keys.filter_map { |k| present(img[k]) }.first || @inline[img["id"]]
    src if src&.match?(RASTER)
  end

  # The <img> of an empty anchor's cell: climb while still inside a single-item
  # cell (one stick= anchor) so we never borrow a neighbour's thumbnail.
  def cell_image(anchor)
    node = anchor.parent
    while node && node.css("a").count { |x| x["href"].to_s.include?("stick=") } <= 1
      img = node.at_css("img")
      return img if img

      node = node.parent
    end
    nil
  end

  # Normalize Google's non-breaking spaces (U+00A0) and trim; nil when empty.
  def norm(str) = str && !(t = str.gsub("\u00A0", " ").strip).empty? ? t : nil
  def clean(el) = norm(el&.text)

  def present(value) = value && !value.empty? ? value : nil

  def unescape(str)
    str.gsub(/\\x(\h\h)/) { $1.to_i(16).chr }.gsub(/\\u(\h{4})/) { [$1.to_i(16)].pack("U") }.gsub('\\/', "/")
  end
end
