#!/usr/bin/env bash
# Run cargo commands for Handy inside the dev container, keeping the host free
# of the Rust toolchain and of Handy's system build dependencies.
#
# Usage: scripts/dev-test.sh <cargo args...>
#   scripts/dev-test.sh test            # run the Rust test suite
#   scripts/dev-test.sh test --lib actions::
#   scripts/dev-test.sh fmt --check
#   scripts/dev-test.sh clippy --lib -- -D warnings
#
# Caching (so repeated runs are incremental, not cold builds):
#   - compiled deps persist in /mnt/7300-23/gh/handy/target
#   - the cargo registry persists in /mnt/7300-23/gh/handy/registry
# The container image is built automatically on first use.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_DIR=/mnt/7300-23/gh/handy
IMAGE=handy-dev

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "== Building $IMAGE image (first run only) ==" >&2
  # --pull: always build from the current base image and package archive so
  # ca-certificates (and everything else) is never frozen by layer caching.
  docker build --pull -f "$REPO_ROOT/Dockerfile.dev" -t "$IMAGE" "$REPO_ROOT"
fi

mkdir -p "$CACHE_DIR/target" "$CACHE_DIR/registry"

exec docker run --rm \
  -v "$REPO_ROOT":/work \
  -v "$CACHE_DIR/target":/cache/target \
  -v "$CACHE_DIR/registry":/home/handy/.cargo/registry \
  -e CARGO_TARGET_DIR=/cache/target \
  -e CMAKE_BUILD_PARALLEL_LEVEL="$(nproc)" \
  -e MAKEFLAGS="-j$(nproc)" \
  -w /work/src-tauri \
  "$IMAGE" cargo "$@"
