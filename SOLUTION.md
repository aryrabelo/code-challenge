# serpapi-code-challenge

Solution to the SerpApi **"Extract Van Gogh Paintings"** code challenge.

> **Challenge:** <https://github.com/serpapi/code-challenge>
> Parse a saved Google SERP HTML page (no extra HTTP requests) and extract the
> knowledge-graph *artworks* carousel as an array of `{ name, extensions, link, image }`.

A layout-resilient Google knowledge-graph extractor. `lib/carousel_parser.rb`
scopes the carousel by Google's durable knowledge-graph `data-attrid` rather than
the hashed CSS classes that rotate per query, and takes each name from the
image's **accessibility (`alt`) text** rather than a fragile div position. It
reproduces the official `expected-array.json` **47/47, field-for-field**, and
generalizes to other layouts: Monet (50), Picasso (45), Leonardo da Vinci (47),
Tarsila pt-BR (42), and a real non-`:works` films carousel (Tarantino, 9) whose
cells are structurally different (empty anchor, `aria-labelledby` title/year,
sibling-`<img>` thumbnail).

## Run

```bash
bundle install
bundle exec rspec                          # full suite, incl. the 47/47 oracle check
bin/extract files/van-gogh-paintings.html  # print the {"artworks": [...]} JSON
```

Ruby 3.x + Nokogiri + RSpec. No network: it parses the saved file.

## Approach

`CarouselParser` parses the SERP with Nokogiri:

- **Carousel scope** — one section, by its durable knowledge-graph `data-attrid`:
  the exact artist `kc:/visual_art/visual_artist:works`, then any `:works`, then
  the first `kc:/<domain>/<type>:<collection>` carousel holding `stick=` anchors
  (a person's films/books). Scoping to one section keeps multi-carousel person
  pages from merging. No hashed-class scoping.
- **name** — the carousel `<img>`'s **`alt`** text. That is Google's
  screen-reader label for the cell and equals the artwork title verbatim; being
  semantic, it survives Google reflowing the cell's div nesting. The structural
  leaf-text divs (paintings) or `aria-labelledby` spans (films) are the fallback
  for cells whose `<img>` carries no `alt`.
- **date / extensions** — the second structural label (a leaf-text div, or the
  second `aria-labelledby` span). `extensions` is omitted when an item has no date.
- **link** — the anchor's root-relative `href`, prefixed with
  `https://www.google.com`; non-Google / `javascript:` / `data:` hrefs are dropped.
- **image** — the gstatic URL the page exposes via `data-src`, or the base64
  embedded in `_setImagesSrc` scripts (JS `\x3d` → `=` decoded), or the data-URI
  in the films cell's sibling `<img>` `src`. Only `https`/raster data-URIs are
  emitted (no `svg`/`js` beacons).

Hardening: invalid UTF-8 is scrubbed, libxml2's node-size cap is lifted (`huge`)
so a giant pre-carousel node can't truncate the DOM, and the inline-image scan
uses possessive quantifiers (no ReDoS).

## Tested against other carousels

Per the challenge's "test against 2 other similar result pages", the parser is
verified against more carousels: **Monet** (50), **Picasso** (45), **Leonardo da
Vinci** (47), a **Portuguese** (pt-BR) page (**Tarsila do Amaral**, 42), a **real
non-`:works` film carousel** (**Quentin Tarantino**, `kc:/people/person:movies`,
9 — empty `<a>`, `aria-labelledby` title/year, sibling `<img>` thumbnail), a
synthetic **non-painting** films carousel (subtitles, not years), and an explicit
**no-carousel** page (→ empty array) — confirming it works across layouts,
locales, and entity types.

## Layout

```
lib/carousel_parser.rb     # the extractor
bin/extract                # CLI: print the JSON for a saved SERP file
spec/                      # RSpec: oracle (47/47) + cross-layout generalization
  fixtures/pages/*.html    # other real carousels (Monet, da Vinci, Picasso, Tarsila, Tarantino)
  fixtures/*.html          # synthetic edge cases (films-carousel, no-carousel)
files/                     # the original challenge files (inputs + oracle)
```

License: MIT (see `LICENSE`).
