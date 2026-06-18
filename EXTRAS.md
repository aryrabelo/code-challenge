# Extras — live fetch-and-serve (on a separate branch)

The graded solution on this branch is **parse-only**: it reads a saved Google
SERP HTML file and extracts the carousel, exactly as the brief asks
(*"no extra HTTP requests"*). Nothing here touches the network.

A second, optional layer — **fetching live Google and serving the same JSON**,
the thing SerpApi productizes — lives on its own branch so it never weighs on
the core:

```
git checkout solution-3-live-fetch
```

## What that branch adds

- **`lib/browser_fetcher.rb`** — drives a headless Chrome (Ferrum) to render the
  JS-injected carousel a plain `Net::HTTP` GET never sees, and returns the HTML.
  Exposed as `bin/extract --browser "<google search url>"`, end-to-end against
  live Google. Includes anti-automation hygiene (undefine `navigator.webdriver`,
  consent cookie, real User-Agent) and `#egress_ip` to confirm a VPN is live.
- **`lib/rate_guard.rb`** — persists fetch timestamps to a state file so the
  throttle holds **across processes/test runs** (raises `TooFrequent` inside the
  cooldown). The browser fetcher checks it before every network hit.
- **VPN/proxy** — `VPN_PROXY=host:port` routes the browser; `REQUIRE_VPN=1`
  refuses to fetch unless a proxy is set.
- **`script/capture_serps.rb`** — uses the fetcher to capture the extra
  cross-layout pages that are committed as fixtures here.

## Why it is split out

Reliably getting Google's rendered carousel at scale is the hard problem SerpApi
sells a service for; live fetching is inherently best-effort. Keeping it off the
graded branch leaves the core a small, dependency-light parser (Nokogiri only),
while the branch preserves the full pipeline for anyone who wants to see it.

The cross-layout test fixtures those scripts produced
(`spec/fixtures/pages/*.html`) are committed on **this** branch too, so the suite
exercises real Monet/Picasso/da Vinci/Tarsila/Tarantino pages with no network.
