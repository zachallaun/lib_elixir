#!/usr/bin/env bash

set -e

test_dir=$(dirname "$(realpath "$0")")

# Run in subshell to ensure we don't change
# the outer shell's current directory.
(
  cd "$test_dir"
  rm -rf _build
  mix local.rebar --force
  mix local.hex --force
  mix deps.get
  mix test
)
