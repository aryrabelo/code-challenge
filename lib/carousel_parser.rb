# frozen_string_literal: true

require "nokogiri"
require "json"
require_relative "section_locator"
require_relative "thumbnail_resolver"
require_relative "cell"

# Extracts a Google knowledge-graph carousel from a saved SERP page into
# { name:, extensions:, link:, image: } items. Orchestrates three collaborators:
# SectionLocator (where the carousel is), ThumbnailResolver (image urls), and
# Cell (one anchor -> one artwork).
class CarouselParser
  def self.from_file(path) = new(File.read(path))

  def initialize(html)
    html = html.to_s.dup.force_encoding("UTF-8").scrub
    @doc = Nokogiri::HTML(html) { |c| c.huge }   # huge: keep libxml from truncating a big DOM
    @thumbnails = ThumbnailResolver.new(html)
  end

  def artworks
    anchors.filter_map { |anchor| Cell.for(anchor, @doc, @thumbnails).artwork }
  end

  def to_h = { "artworks" => artworks.map { |art| art.transform_keys(&:to_s) } }
  def to_json(*args) = JSON.generate(to_h, *args)

  private

  def anchors
    SectionLocator.new(@doc).container.css('a[href*="/search"][href*="stick="]')
  end
end
