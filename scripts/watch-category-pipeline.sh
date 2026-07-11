#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
command -v fswatch >/dev/null 2>&1 || {
  echo "fswatch is required" >&2
  exit 127
}

echo "watching category/formal/Julia sources under $ROOT"
fswatch -o \
  "$ROOT/category" \
  "$ROOT/specs/ledger.toml" \
  "$ROOT/specs/category-impact.toml" \
  "$ROOT/formal" \
  "$ROOT/src" \
  "$ROOT/test" |
while read -r _; do
  julia --project="$ROOT" "$ROOT/bin/eriec-category-pipeline.jl" check || true
done
