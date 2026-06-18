# serpapi-code-challenge

Solution to the SerpApi **"Extract Van Gogh Paintings"** code challenge.

> **Challenge:** <https://github.com/serpapi/code-challenge>
> Parse a saved Google SERP HTML page (no extra HTTP requests) and extract the
> knowledge-graph *artworks* carousel as an array of `{ name, extensions, link, image }`.

> **Branch `solution-3` — lean *and* complete.** One **109-line** parser (vs 232 on
> `solution`) that still covers every carousel: the Van Gogh oracle, the works carousels,
> AND the real non-`:works` `aria-labelledby` films carousel that the 61-line `solution-2`
> traded away. Same coverage as `solution`, ~53% less code.

**Status:** reproduces the official `expected-array.json` **47/47, field-for-field**, and
generalizes to Monet (50), Picasso (45), Tarsila pt-BR (42) and a real non-`:works` films
carousel (Tarantino, 9). Ruby 3.3 + RSpec, green in Docker and locally.

## Run

```bash
# Docker (reproducible, no local Ruby needed):
docker compose run --rm test          # full RSpec suite   (docker-compose also works)
docker compose run --rm test bin/verify

# Local — toolchain pinned with mise (mise.toml → Ruby 3.3.6):
mise install
mise exec -- bundle install
mise exec -- bundle exec rspec

# Or with any Ruby 3.x on PATH:
bundle install && bundle exec rspec
ruby bin/verify        # quick offline check vs the oracle → "PERFECT 47/47 ✅"
```

## CLI

```bash
bin/extract files/van-gogh-paintings.html        # parse a local SERP file
bin/extract --url     "https://www.google.com/search?q=Van+Gogh+paintings&hl=en"  # plain HTTP
bin/extract --browser "https://www.google.com/search?q=Van+Gogh+paintings&hl=en"  # headless render
```

Prints the SerpApi-style `{"artworks": [...]}` JSON. Three ways to get the HTML:

- **local file** — the challenge's own use case (no network).
- **`--url`** — `SerpFetcher` (plain `Net::HTTP`). Fast, but Google does **not** include
  the JS-rendered carousel in the raw HTML. In tests this path is replayed from a
  recorded **VCR cassette** — the network is recorded once and never hit live again.
- **`--browser`** — `BrowserFetcher` drives a **headless Chrome** (Ferrum) to run the
  JS so the carousel appears. Fully in-repo (no external browser). Chrome is a runtime
  prereq (`CHROME_PATH` or auto-detected).

### Anti-block safeguards

- **Rate guard** — every live fetch goes through `RateGuard`, which persists timestamps
  to a state file so it throttles **across processes/test runs** (raises `TooFrequent`
  inside the cooldown). Tests swap in a `NullGuard`.
- **VPN/proxy** — set `VPN_PROXY=host:port` (or a full proxy URL) to route the browser;
  `REQUIRE_VPN=1` refuses to fetch unless a proxy is set, and `BrowserFetcher#egress_ip`
  asks the browser what public IP it's leaving from, so you can confirm the VPN is live.
- Reliably getting Google's rendered carousel at scale is the hard problem SerpApi sells
  a service for; treat live fetching as best-effort and commit captured fixtures for tests.

## Approach

`CarouselParser` (`lib/carousel_parser.rb`, 109 lines) parses the SERP with Nokogiri:

- **Carousel scope** — one section, by its durable knowledge-graph `data-attrid`: the
  exact artist `kc:/visual_art/visual_artist:works`, then any `:works`, then the first
  `kc:/<domain>/<type>:<collection>` carousel holding `stick=` anchors (a person's
  films/books). Scoping to one section keeps multi-carousel person pages from merging.
- **two cell shapes** — a painting cell nests the name/date in leaf-text divs and the
  `<img>` inside the anchor; a films cell has an empty anchor whose title/year are
  `aria-labelledby` spans and whose thumbnail is a sibling `<img>`. `labels` and `image`
  each fall through from the first shape to the second. `extensions` is omitted when an
  item has no date.
- **link** — the anchor's root-relative `href`, prefixed with `https://www.google.com`.
- **image** — the gstatic URL the page exposes via `data-src`, or the base64 embedded in
  `_setImagesSrc` scripts (JS `\x3d` → `=` decoded), or the data-URI in the films cell's
  sibling `<img>` `src`. Only `https`/raster data-URIs are emitted.

`SerpFetcher` (`lib/serp_fetcher.rb`) is only used to acquire extra test pages; in the
suite it is replayed from a **VCR cassette**, so tests never hit Google.

## Tested against other carousels

Per the challenge, the parser is verified against more carousels: **Monet** (50) and
**Picasso** (45), a **Portuguese** (pt-BR) page (**Tarsila do Amaral**, 42), a **real
non-`:works` film carousel** (**Quentin Tarantino**, `kc:/people/person:movies`, 9 —
its cells are structurally different: the `<a>` is empty, the title/year come from
`aria-labelledby` spans, and the thumbnail is a sibling `<img>`), a synthetic
**non-painting** films carousel (subtitles, not years), and an explicit **no-carousel**
page (→ empty array) — confirming it works across layouts, locales, and entity types.

## Development

- **TDD** — behaviour is specified in `spec/` first. The extractor's contract lives in
  `spec/carousel_parser_spec.rb`.
- **Lefthook** — `lefthook install` wires pre-commit/pre-push to run the suite, so a red
  suite can't be committed or pushed.
- **mise** pins Ruby; **Docker Compose** gives a clean reproducible run.

## Layout

```
lib/                       # the gem (extractor, fetcher, version, entrypoint)
spec/                      # RSpec: oracle + generalization + VCR replay
  fixtures/pages/*.html    # real fetched carousels (Monet, Tarsila pt-BR, Tarantino films)
  fixtures/*.html          # synthetic edge cases (films-carousel, no-carousel)
  fixtures/cassettes/      # recorded HTTP interactions
bin/verify                 # dependency-free oracle diff
files/            # the original challenge files (inputs + oracle)
Dockerfile, docker-compose.yml, mise.toml, lefthook.yml
```

License: MIT (see `LICENSE`).
