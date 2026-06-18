# serpapi-code-challenge

Solution to the SerpApi "Extract Van Gogh Paintings" challenge.

> Challenge: <https://github.com/serpapi/code-challenge>
> Parse a saved Google SERP HTML page (no extra HTTP) and return the
> knowledge-graph artworks carousel as an array of `{ name, extensions, link, image }`.

`lib/carousel_parser.rb` parses the saved page with Nokogiri. It reproduces the
official `expected-array.json` exactly, 47 of 47, every field. It also runs on
other artists: Monet (50), Picasso (45), Leonardo da Vinci (47), a pt-BR page for
Tarsila do Amaral (42), and a person's films carousel (Tarantino, 9), which has a
different cell shape (empty anchor, title and year in `aria-labelledby` spans,
thumbnail in a sibling `<img>`).

## Run

```bash
bundle install
bundle exec rake                           # RSpec (incl. the 47/47 oracle) + RuboCop
bundle exec rspec                          # just the tests
bundle exec rubocop                        # just the complexity / bug check
bin/extract files/van-gogh-paintings.html  # print the {"artworks": [...]} JSON
```

Ruby 3.x, Nokogiri, RSpec, RuboCop. Nothing hits the network; it reads the file.
The RuboCop config (`.rubocop.yml`) only checks complexity (Metrics) and likely
bugs (Lint), not cosmetic style.

## Approach

The carousel is found by its knowledge-graph `data-attrid`, not by CSS class
names, which are hashed and rotate per query. `SectionLocator` tries the exact
artist-works attrid (`kc:/visual_art/visual_artist:works`), then any `:works`,
then the first `kc:/<domain>/<type>:<collection>` section that holds `stick=`
anchors (a person's films or books). Picking one section keeps a page with
several carousels from bleeding into each other.

Each anchor becomes one item:

- name: the `<img>` `alt`. Google writes the title there as the screen-reader
  text, so it matches what's shown and doesn't move when Google reshuffles the
  surrounding divs. When an image has no `alt` (the films cell), it falls back to
  the leaf-text divs or the `aria-labelledby` spans.
- extensions: the date next to the name (second leaf-text div, or second aria
  span). Left out when the item has no date.
- link: the anchor's `/...` href with `https://www.google.com` in front.
  Anything that isn't a root-relative Google link is dropped (`javascript:`,
  `data:`, and so on).
- image: the gstatic URL in `data-src`, or the base64 Google injects through
  `_setImagesSrc` scripts (the `\x3d`-style escapes get decoded back to `=`), or
  the data-URI in a films cell's sibling `<img>`. Only `https` and raster
  data-URIs make it out, no svg or js.

A few defensive bits, since the input is a real Google page: bad UTF-8 is
scrubbed before parsing, libxml2's node-size cap is raised (`huge`) so a big node
ahead of the carousel can't cut the DOM short, and the inline-image regex uses
possessive quantifiers so it won't backtrack on adversarial input.

The work is split into small pieces: `SectionLocator` finds the section,
`ThumbnailResolver` builds the inline-base64 index and sanitizes thumbnail URLs,
and `Cell` (with `NestedCell` and `LinkedCell`) turns one anchor into one item.
`CarouselParser` wires them together.

## Tested against other carousels

The challenge asks for two other pages; there are more. Real fetched pages for
Monet (50), Picasso (45), Leonardo da Vinci (47), and Tarsila do Amaral in pt-BR
(42). A real films carousel for Quentin Tarantino (`kc:/people/person:movies`,
9) to exercise the empty-anchor / aria-labelledby / sibling-image shape. A
synthetic films carousel where the subtitle isn't a year, to check that
`extensions` doesn't pick up the title. And a page with no carousel, which
returns an empty array.

## Layout

```
lib/
  carousel_parser.rb     # orchestrator
  section_locator.rb     # find the carousel section by data-attrid
  thumbnail_resolver.rb  # inline base64 index + thumbnail URL
  cell.rb                # Cell + NestedCell / LinkedCell (one anchor -> one item)
bin/extract              # print the JSON for a saved SERP file
spec/                    # RSpec: oracle (47/47) + cross-layout + unit specs
  fixtures/pages/*.html  # other real carousels (Monet, da Vinci, Picasso, Tarsila, Tarantino)
  fixtures/*.html        # synthetic edge cases (films-carousel, no-carousel)
files/                   # the original challenge files (inputs + oracle)
```

License: MIT (see `LICENSE`).
