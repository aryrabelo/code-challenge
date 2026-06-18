# frozen_string_literal: true

# Finds the one carousel section in a parsed SERP, by its stable knowledge-graph
# data-attrid (the hashed CSS classes rotate per query). Most specific match
# first; falls back to the whole document.
class SectionLocator
  ENTITY = %r{kc:/\w+/\w+:\w+}

  def initialize(doc)
    @doc = doc
  end

  def container
    artist_works || any_works || entity_carousel || @doc
  end

  private

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
end
