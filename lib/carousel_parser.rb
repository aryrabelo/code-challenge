# frozen_string_literal: true

require "nokogiri"
require "json"

# Extracts a Google knowledge-graph carousel from a saved SERP page into
# { name:, extensions:, link:, image: } items. Proven on the Van Gogh oracle and
# generalizes to other artists' :works carousels and a person's films carousel.
class CarouselParser
  GOOGLE = "https://www.google.com"
  ENTITY = %r{kc:/\w+/\w+:\w+}
  RASTER = %r{\Ahttps://|\Adata:image/(?:png|jpe?g|gif|webp);base64,}

  def self.from_file(path) = new(File.read(path))

  def initialize(html)
    @html = html.to_s.dup.force_encoding("UTF-8").scrub
    @doc = Nokogiri::HTML(@html) { |c| c.huge }   # huge: keep libxml from truncating a big DOM
    @inline = inline_images
  end

  def artworks
    container.css('a[href*="/search"][href*="stick="]').filter_map { |anchor| item(anchor) }
  end

  def to_h = { "artworks" => artworks.map { |art| art.transform_keys(&:to_s) } }
  def to_json(*args) = JSON.generate(to_h, *args)

  private

  # One carousel section, picked by its stable knowledge-graph data-attrid (the
  # hashed CSS classes rotate per query). Most specific match first.
  def container
    artist_works || any_works || entity_carousel || @doc
  end

  def artist_works
    @doc.at_css('[data-attrid="kc:/visual_art/visual_artist:works"]')
  end

  def any_works
    sections.find { |section| section["data-attrid"].to_s.end_with?(":works") }
  end

  def entity_carousel
    sections.find do |section|
      section["data-attrid"].to_s.match?(ENTITY) && section.at_css('a[href*="stick="]')
    end
  end

  def sections = @doc.css("[data-attrid]")

  def item(anchor)
    name, date = labels(anchor)
    name = alt_name(anchor) || name
    return unless name

    art = { name: name }
    art[:extensions] = [date] if date
    art[:link] = GOOGLE + anchor["href"] if anchor["href"].start_with?("/")
    art[:image] = image(anchor)
    art
  end

  # The image alt is Google's screen-reader title for the cell and the most
  # durable name; structural labels are the fallback when an <img> has no alt.
  def alt_name(anchor)
    img = anchor.at_css("img") || cell_image(anchor)
    img && norm(img["alt"])
  end

  # [name, date]. A painting cell stacks them in plain-text <div>s; a films cell
  # leaves the anchor empty and names them in aria-labelledby <span>s.
  def labels(anchor)
    divs = text_divs(anchor)
    return divs.first(2) if divs.any?

    aria_labels(anchor)
  end

  def text_divs(anchor)
    anchor.css("div").select { |div| leaf_text?(div) }.map { |div| clean(div) }
  end

  def leaf_text?(div)
    div.children.any? && div.children.all?(&:text?) && !div.text.strip.empty?
  end

  def aria_labels(anchor)
    anchor["aria-labelledby"].to_s.split.first(2).map { |id| clean(@doc.at_css("##{id}")) }
  end

  # A painting cell's <img> is inside the anchor; a films cell's sits beside it.
  def image(anchor)
    if (inner = anchor.at_css("img"))
      src = inner_thumbnail(inner)
    elsif (sibling = cell_image(anchor))
      src = sibling_thumbnail(sibling)
    end
    src if src&.match?(RASTER)
  end

  # A painting's inner <img> holds a 1x1 placeholder in src (the real bytes load
  # later via _setImagesSrc), so read data-src or the script-embedded base64.
  def inner_thumbnail(img)
    present(img["data-src"]) || @inline[img["id"]]
  end

  # A films <img> carries the data-URI directly in src.
  def sibling_thumbnail(img)
    present(img["src"]) || present(img["data-src"]) || @inline[img["id"]]
  end

  # The thumbnail for an empty (films) anchor: climb to the nearest ancestor that
  # holds an <img>, stopping before one that wraps another cell.
  def cell_image(anchor)
    node = anchor.parent
    until node.nil? || wraps_other_cell?(node)
      img = node.at_css("img")
      return img if img

      node = node.parent
    end
  end

  def wraps_other_cell?(node)
    node.css('a[href*="stick="]').size > 1
  end

  # Inline base64 thumbnails Google injects as `var s='data:…';var ii=['<id>']`,
  # mapped <img id> => data-URI (with \x3d / \u… / \/ escapes decoded).
  def inline_images
    @html.scan(%r{var s='(data:image/[^']*+)';var ii=\[([^\]]*+)\]})
         .flat_map { |s, ii| ii.scan(/'([^']+)'/).map { |(id)| [id, unescape(s)] } }
         .to_h
  end

  def unescape(str)
    str.gsub(/\\x(\h\h)/) { $1.to_i(16).chr }
       .gsub(/\\u(\h{4})/) { [$1.to_i(16)].pack("U") }
       .gsub('\\/', "/")
  end

  def norm(str) = str && !(t = str.gsub("\u00A0", " ").strip).empty? ? t : nil
  def clean(node) = norm(node&.text)
  def present(value) = value && !value.empty? ? value : nil
end
