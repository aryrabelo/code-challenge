# frozen_string_literal: true

# Resolves a carousel <img> to a safe thumbnail URL.
#
# Google delivers thumbnails three ways: a gstatic URL in data-src, base64
# injected by `var s='data:…';var ii=['<img id>']` scripts (keyed by id), or a
# data-URI directly in src. Only https / raster data-URIs are emitted.
class ThumbnailResolver
  RASTER = %r{\Ahttps://|\Adata:image/(?:png|jpe?g|gif|webp);base64,}

  def initialize(html)
    @inline = build_index(html)
  end

  # allow_src: also read the <img> src. A sibling cell's data-URI lives there,
  # but a nested cell's src is only a 1x1 placeholder, so those callers pass false.
  def resolve(img, allow_src:)
    return unless img

    url = (allow_src && present(img["src"])) || present(img["data-src"]) || @inline[img["id"]]
    url if url&.match?(RASTER)
  end

  private

  def build_index(html)
    html.scan(%r{var s='(data:image/[^']*+)';var ii=\[([^\]]*+)\]})
        .flat_map { |s, ii| ii.scan(/'([^']+)'/).map { |(id)| [id, unescape(s)] } }
        .to_h
  end

  # Google writes the base64 as a JS string literal: `=` padding becomes \x3d,
  # and \uXXXX / \/ also appear. Decode them back to the raw data-URI.
  def unescape(str)
    str.gsub(/\\x(\h\h)/) { $1.to_i(16).chr }
       .gsub(/\\u(\h{4})/) { [$1.to_i(16)].pack("U") }
       .gsub('\\/', "/")
  end

  def present(value) = value && !value.empty? ? value : nil
end
