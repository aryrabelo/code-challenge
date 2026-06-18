#!/usr/bin/env bash
# Keep the bundle (stored in a named volume) in sync with Gemfile.lock on every
# `up`/`run`, then exec the requested command. This is the Ruby-on-Whales dev
# pattern: gems are installed once into the volume, not baked into the image.
set -e

bundle check >/dev/null 2>&1 || bundle install

exec "$@"
