#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
repo_root="$(cd "$repo_root" && pwd -P)"

exec julia --startup-file=no --project="$repo_root" \
  "$repo_root/tools/verify/g3c_evidence_validation.jl" "$@"
