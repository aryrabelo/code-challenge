# serpapi-code-challenge

Solution to the SerpApi **"Extract Van Gogh Paintings"** code challenge.

> **Challenge:** <https://github.com/serpapi/code-challenge>
> Parse a saved Google SERP HTML page (no extra HTTP requests) and extract the
> knowledge-graph *artworks* carousel as an array of `{ name, extensions, link, image }`.

**Status:** reproduces the official `expected-array.json` **47/47, field-for-field**,
and generalizes to other carousels (Monet, Picasso). Ruby 3.3 + RSpec, green in
Docker and locally.

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

`CarouselParser` (`lib/carousel_parser.rb`) parses the SERP with Nokogiri:

- **Carousel scope** — finds the section by its *stable* knowledge-graph `data-attrid`:
  the exact artist `kc:/visual_art/visual_artist:works`, then any `:works` section, then
  (for non-artist pages) the first `kc:/<domain>/<type>:<collection>` carousel that holds
  `stick=` anchors — so it generalizes to films/books. No hashed-class scoping.
- **name / date** — purely structural: each item is two stacked leaf-text divs (name
  first, optional subtitle/date second), so it never depends on Google's rotating class
  names. `extensions` is **omitted** when an item has no date (the oracle drops it for 4).
- **link** — the item anchor's `href`, absolutized against `https://www.google.com`.
- **image** — two branches: lazy items expose a gstatic URL via `data-src`; the first
  ~8 visible items embed base64 in `_setImagesSrc(['<img id>'], 's')` scripts, which we
  decode (including JS `\x3d` → `=` escapes) into the inline `data:image` URI.

`SerpFetcher` (`lib/serp_fetcher.rb`) is only used to acquire extra test pages; in the
suite it is replayed from a **VCR cassette**, so tests never hit Google.

## Tested against other carousels

Per the challenge, the parser is verified against more carousels: **Monet** (50) and
**Picasso** (45), a **Portuguese** (pt-BR) page (**Tarsila do Amaral**, 42), a synthetic
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
  fixtures/pages/*.html    # extra carousels (Monet, Picasso)
  fixtures/cassettes/      # recorded HTTP interactions
bin/verify                 # dependency-free oracle diff
files/            # the original challenge files (inputs + oracle)
Dockerfile, docker-compose.yml, mise.toml, lefthook.yml
```

License: MIT (see `LICENSE`).
