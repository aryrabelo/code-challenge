# frozen_string_literal: true

require "thumbnail_resolver"

# Resolvable in isolation — the payoff of splitting thumbnail logic out.
RSpec.describe ThumbnailResolver do
  def img(markup) = Nokogiri::HTML(markup).at_css("img")

  it "returns an https data-src thumbnail" do
    node = img('<img data-src="https://gstatic/x.png">')
    expect(described_class.new("").resolve(node, allow_src: false)).to eq("https://gstatic/x.png")
  end

  it "decodes an inline base64 thumbnail referenced by id" do
    html = %(<script>var s='data:image/jpeg;base64,AAA\\x3d';var ii=['img1']</script>)
    expect(described_class.new(html).resolve(img('<img id="img1">'), allow_src: false))
      .to eq("data:image/jpeg;base64,AAA=")
  end

  it "rejects a non-raster scheme (e.g. a tracking beacon)" do
    node = img('<img data-src="//evil.tld/beacon.gif">')
    expect(described_class.new("").resolve(node, allow_src: false)).to be_nil
  end

  it "ignores a nested cell's placeholder src unless src is allowed" do
    node = img('<img src="data:image/gif;base64,PLACEHOLDER">')
    expect(described_class.new("").resolve(node, allow_src: false)).to be_nil
    expect(described_class.new("").resolve(node, allow_src: true)).to eq("data:image/gif;base64,PLACEHOLDER")
  end
end
