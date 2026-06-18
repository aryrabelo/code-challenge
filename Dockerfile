# syntax=docker/dockerfile:1
# Pinned Ruby, matching mise.toml. Gems are installed at run time into a named
# volume (see docker-compose.yml + docker-entrypoint.sh) — the "Ruby on Whales"
# pattern — so a Gemfile change doesn't force a full image rebuild.
ARG RUBY_VERSION=3.3.6
FROM ruby:${RUBY_VERSION}-slim

ENV BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_JOBS=4 \
    LANG=C.UTF-8 \
    TZ=UTC

RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends build-essential git \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["bundle", "exec", "rspec"]
