#!/usr/bin/env bash
# Run Julia tests while keeping complete output in a create-only log.
set -o pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root" || exit 1

target="${1:-}"
log_arg="${2:-}"
if [[ -n "$log_arg" ]]; then
  log="$log_arg"
  mkdir -p "$(dirname "$log")" || exit 2
  if ! (umask 077; set -o noclobber; : >"$log") 2>/dev/null; then
    echo "ERROR log path already exists or cannot be created: $log" >&2
    exit 2
  fi
else
  log_dir="logs/gates/quiet"
  mkdir -p "$log_dir" || exit 2
  if ! log="$(mktemp "$log_dir/test-$(date +%Y%m%d-%H%M%S)-$$.log.XXXXXX")"; then
    echo "ERROR could not create a unique log in: $log_dir" >&2
    exit 2
  fi
fi

if [[ -n "$target" ]]; then
  julia_command=(julia --project=. -e 'using Test; using ERIEC; include(only(ARGS))' "$target")
else
  julia_command=(julia --project=. -e 'using Pkg; Pkg.test()')
fi

if "${julia_command[@]}" >>"$log" 2>&1; then
  echo "PASS log=$log"
  grep -A2 "Test Summary" "$log" | tail -6 || true
  exit 0
else
  echo "FAIL log=$log"
  grep -nE "Error During Test|Test Failed|ERROR:|LoadError" "$log" | head -20
  exit 1
fi
