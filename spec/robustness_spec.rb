# frozen_string_literal: true

require "carousel_parser"

# Hardening driven by the autoresearch:scenario edge-case sweep (12 dimensions).
RSpec.describe "robustness" do
  describe CarouselParser do
    it "does not crash on invalid UTF-8 input" do
      # UTF-8-tagged bytes with an invalid sequence — what File.read yields for a
      # page with bad bytes; String#scan would otherwise raise here.
      bytes = "\xff\xfe<html><body></body></html>".dup.force_encoding("UTF-8")
      expect(bytes.valid_encoding?).to be(false)
      expect { CarouselParser.new(bytes).artworks }.not_to raise_error
      expect(CarouselParser.new(bytes).artworks).to eq([])
    end

    it "never emits javascript: links or unsafe (non-https/non-data:image) image schemes" do
      html = %(<div data-attrid="kc:/x/y:works"><a href="javascript:alert(1)//search?stick=z">) +
             %(<img data-src="//evil.tld/beacon.gif?leak=1"><div><div>Evil</div></div></a></div>)
      item = CarouselParser.new(html).artworks.first
      expect(item[:name]).to eq("Evil")
      expect(item[:link]).to be_nil
      expect(item[:image]).to be_nil
    end
  end
end
