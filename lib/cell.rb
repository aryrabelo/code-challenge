# frozen_string_literal: true

# One carousel cell: turns a single <a> anchor into an artwork hash.
#
# Two DOM shapes share the same algorithm (name = image alt or first label, then
# date / link / image) and differ only in WHERE the labels and image live, so
# they are template-method subclasses:
#   NestedCell  — labels + <img> nested inside the anchor (artist works, and the
#                 inline films/books carousels).
#   LinkedCell  — empty anchor whose labels are aria-labelledby <span>s and whose
#                 thumbnail is a sibling <img> (a person's films carousel).
class Cell
  GOOGLE = "https://www.google.com"

  # Pick the cell shape: a nested <img> means the labels are nested too.
  def self.for(anchor, doc, thumbnails)
    shape = anchor.at_css("img") ? NestedCell : LinkedCell
    shape.new(anchor, doc, thumbnails)
  end

  def initialize(anchor, doc, thumbnails)
    @anchor = anchor
    @doc = doc
    @thumbnails = thumbnails
  end

  # The artwork hash, or nil when the cell has no name (not a real item).
  def artwork
    return unless name

    art = { name: name }
    art[:extensions] = [date] if date
    art[:link] = link if link
    art[:image] = image
    art
  end

  private

  attr_reader :anchor, :doc, :thumbnails

  # The image alt is Google's screen-reader title and the most durable name; the
  # structural label is the fallback when the <img> carries no alt.
  def name = norm(image_node&.[]("alt")) || labels[0]
  def date = labels[1]

  def link
    href = anchor["href"].to_s
    GOOGLE + href if href.start_with?("/")
  end

  def image = thumbnails.resolve(image_node, allow_src: allow_src?)

  # Subclass hooks.
  def labels = raise(NotImplementedError)
  def image_node = raise(NotImplementedError)
  def allow_src? = raise(NotImplementedError)

  def norm(str) = str && !(t = str.gsub("\u00A0", " ").strip).empty? ? t : nil
  def clean(node) = norm(node&.text)
end

# Labels and <img> nested inside the anchor.
class NestedCell < Cell
  private

  def image_node = anchor.at_css("img")

  # A nested <img> shows a 1x1 placeholder in src (the real bytes arrive via the
  # _setImagesSrc script), so its src must be ignored.
  def allow_src? = false

  def labels
    anchor.css("div").select { |div| leaf_text?(div) }.map { |div| clean(div) }
  end

  def leaf_text?(div)
    div.children.any? && div.children.all?(&:text?) && !div.text.strip.empty?
  end
end

# Empty anchor: labels are aria-labelledby <span>s; thumbnail is a sibling <img>.
class LinkedCell < Cell
  private

  def allow_src? = true # the sibling <img> carries the data-URI directly in src

  def labels
    anchor["aria-labelledby"].to_s.split.first(2).map { |id| clean(doc.at_css("##{id}")) }
  end

  # Climb to the nearest ancestor holding an <img>, stopping before one that wraps
  # another cell, so we never borrow a neighbour's thumbnail.
  def image_node
    node = anchor.parent
    until node.nil? || wraps_other_cell?(node)
      img = node.at_css("img")
      return img if img

      node = node.parent
    end
  end

  def wraps_other_cell?(node) = node.css('a[href*="stick="]').size > 1
end
