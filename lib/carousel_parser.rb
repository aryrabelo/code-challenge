# frozen_string_literal: true

require "nokogiri"
require "json"

# Extracts the "artworks" knowledge-graph carousel from a Google SERP HTML page.
#
# The challenge target is the Van Gogh paintings carousel, but the extractor is
# written structurally so it generalizes to other carousels with the same shape
# (each item = an <a> linking to /search?...stick=... that holds a thumbnail,
# a name, and a year/subtitle).
#
# Output: an Array of Hashes with :name, :extensions (Array, usually [year]),
# :link (absolute google.com URL) and :image (inline data-URI thumbnail when the
# page embeds it, otherwise the gstatic thumbnail URL the page references).
module SerpapiCodeChallenge; end

class SerpapiCodeChallenge::CarouselParser
  GOOGLE = "https://www.google.com"

  # Stable knowledge-graph section attributes that hold an artist/person's
  # works carousel. Hashed CSS classes (e.g. iELo6) change per query; these
  # data-attrid values are far more durable across pages.
  WORKS_ATTRIDS = [
    "kc:/visual_art/visual_artist:works",
  ].freeze

  # Any knowledge-graph entity carousel: kc:/<domain>/<type>:<collection>
  # (e.g. :works, :films, :books, :tv_shows). Used as a last-resort generic
  # match so the parser reaches non-artist carousels too.
  ATTR_ID_REGEX = %r{kc:/\w+/\w+:\w+}.freeze

  def self.from_file(path)
    new(File.read(path))
  end

  def initialize(html)
    # Scrub invalid UTF-8 so String#scan / Nokogiri can't crash on bad bytes
    # (File.read yields UTF-8-tagged bytes that may contain invalid sequences).
    @html = html.to_s.dup.force_encoding("UTF-8").scrub
    # `huge` lifts libxml2's node-size cap, so a giant script/text node before
    # the carousel can't silently truncate the DOM to zero anchors.
    @doc = Nokogiri::HTML(@html) { |config| config.huge }
    @image_index = build_image_index
  end

  # @return [Array<Hash>] one symbol-keyed hash per carousel item
  def artworks
    carousel_anchors.map { |a| build_artwork(a) }.compact
  end

  # The SerpApi-style envelope, string-keyed and ready to serialize:
  #   { "artworks" => [ { "name" => ..., "extensions" => [...], ... } ] }
  def to_h
    { "artworks" => artworks.map { |artwork| artwork.transform_keys(&:to_s) } }
  end

  def to_json(*args)
    JSON.generate(to_h, *args)
  end

  private

  # The item anchors of the works carousel: scope to the stable knowledge-graph
  # "works" section, then take every anchor that looks like a carousel item.
  def carousel_anchors
    scoped_anchors
  end

  def scoped_anchors
    container = works_container
    scope = container || @doc
    scope.css("a").select { |a| carousel_anchor?(a) }
  end

  # Locate the carousel's knowledge-graph section. Prefer the exact artist-works
  # attrid, then any ":works" section, then — for non-artist pages — the first
  # generic entity carousel that actually contains carousel (stick=) anchors.
  def works_container
    WORKS_ATTRIDS.each do |attrid|
      node = @doc.at_css(%([data-attrid="#{attrid}"]))
      return node if node
    end

    sections = @doc.css("[data-attrid]")
    sections.find { |n| n["data-attrid"].to_s.end_with?(":works") } ||
      sections.find do |n|
        n["data-attrid"].to_s.match?(ATTR_ID_REGEX) &&
          n.css("a").any? { |a| a["href"].to_s.include?("stick=") }
      end
  end

  # A carousel item anchor points at a /search?...stick=... result (the
  # knowledge-graph carousel signature) and carries a thumbnail.
  def carousel_anchor?(anchor)
    href = anchor["href"].to_s
    href.include?("/search") && href.include?("stick=") && !anchor.at_css("img").nil?
  end

  # Each item is two stacked leaf-text divs: the name first, then an optional
  # subtitle/date — keyed on structure, not on Google's hashed CSS classes
  # (which rotate per query). text_blocks is computed once per item.
  def build_artwork(anchor)
    name, subtitle = text_blocks(anchor).first(2).map { |el| clean(el) }
    return nil if name.nil?

    # Mirror SerpApi's shape: `extensions` is present only when the item carries
    # a date/subtitle; otherwise the key is omitted entirely.
    artwork = { name: name }
    artwork[:extensions] = [subtitle] if subtitle
    artwork[:link] = absolute(anchor["href"])
    artwork[:image] = image_of(anchor)
    artwork
  end

  # The thumbnail. Items the page renders inline expose their base64 via an
  # _setImagesSrc script keyed by the <img> id; lazy items only reference a
  # gstatic URL through data-src (fetching it would need an extra request, so we
  # surface the URL the page already gives us).
  def image_of(anchor)
    img = anchor.at_css("img")
    return nil unless img

    data_src = img["data-src"]
    candidate = data_src && !data_src.empty? ? data_src : @image_index[img["id"]]
    safe_image(candidate)
  end

  # Only surface a thumbnail we trust: an https URL or an inline raster data-URI.
  # Rejects javascript:, protocol-relative //beacons, and data:image/svg+xml.
  def safe_image(value)
    return nil if value.nil? || value.empty?
    return value if value.start_with?("https://")
    return value if value.match?(%r{\Adata:image/(?:png|jpe?g|gif|webp);base64,})

    nil
  end

  # Absolutize a carousel href. Accept only root-relative Google paths (the real
  # carousel links) or an already-absolute google.com URL; reject javascript:,
  # data:, and protocol-relative hrefs so the output can't carry an XSS payload.
  def absolute(href)
    return nil if href.nil? || href.empty?
    return GOOGLE + href if href.start_with?("/")

    href.start_with?("#{GOOGLE}/") ? href : nil
  end

  # Leaf text divs under the anchor: a div whose children are all text nodes
  # (stricter than "no nested div" — also rejects a div wrapping a <span>), with
  # non-empty text. First such div = name, second = subtitle/date.
  def text_blocks(anchor)
    anchor.css("div").select do |d|
      d.children.any? && d.children.all?(&:text?) && !d.text.strip.empty?
    end
  end

  def clean(el)
    return nil if el.nil?
    # Normalize Google's non-breaking spaces (U+00A0) before trimming.
    text = el.text.gsub(" ", " ").strip
    text.empty? ? nil : text
  end

  # Maps an <img> id to its inline base64 data-URI, parsed from the page's
  # `(function(){var s='data:image/...';var ii=['<id>'];_setImagesSrc(ii,s)})()`
  # bootstrap scripts.
  def build_image_index
    index = {}
    # Possessive quantifiers (*+) match atomically — no backtracking — so an
    # adversarial page can't drive this scan into ReDoS.
    @html.scan(%r{var s='(data:image/[^']*+)';var ii=\[([^\]]*+)\]}) do |data, ids|
      decoded = unescape_js(data)
      ids.scan(/'([^']+)'/).each { |(id)| index[id] = decoded }
    end
    index
  end

  # Google writes the base64 thumbnails as JS string literals, escaping `=`
  # padding as `\x3d` (and occasionally `\uXXXX` / `\/`). Decode those back so
  # the stored data-URI matches the rendered image byte-for-byte.
  def unescape_js(str)
    str
      .gsub(/\\x([0-9a-fA-F]{2})/) { Regexp.last_match(1).to_i(16).chr }
      .gsub(/\\u([0-9a-fA-F]{4})/) { [Regexp.last_match(1).to_i(16)].pack("U") }
      .gsub('\\/', "/")
  end
end
