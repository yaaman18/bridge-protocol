#!/usr/bin/env bash
# Run G1 while keeping complete output in a create-only log.
set -o pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root" || exit 1

log_arg="${1:-}"
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
  if ! log="$(mktemp "$log_dir/G1-$(date +%Y%m%d-%H%M%S)-$$.log.XXXXXX")"; then
    echo "ERROR could not create a unique log in: $log_dir" >&2
    exit 2
  fi
fi

if lake build >>"$log" 2>&1; then
  echo "PASS $(tail -1 "$log") log=$log"
else
  echo "FAIL log=$log"
  grep -nE "error:|warning:.*sorry|✖" "$log" | head -20
  exit 1
fi
