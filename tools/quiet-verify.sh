#!/usr/bin/env bash
# Run verification-practice mutation and ratchet checks into a create-only log.
set -o pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root" || exit 1

log="${1:-}"
shift || true
if [[ -z "$log" ]]; then
  echo "ERROR usage: tools/quiet-verify.sh logs/gates/<batch>/G3V-<timestamp>.log --base-ref <commit>" >&2
  exit 2
fi
case "$log" in
  logs/gates/*) ;;
  *)
    echo "ERROR log must be a relative path below logs/gates/: $log" >&2
    exit 2
    ;;
esac
if [[ "$log" == *"/../"* || "$log" == ../* || "$log" == */.. ]]; then
  echo "ERROR parent traversal is forbidden in log path: $log" >&2
  exit 2
fi
if [[ "${1:-}" != "--base-ref" || -z "${2:-}" || -n "${3:-}" ]]; then
  echo "ERROR --base-ref <commit> is mandatory" >&2
  exit 2
fi
base_ref="$2"
if [[ ! "$base_ref" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*$ || "$base_ref" == *..* ]]; then
  echo "ERROR base-ref contains unsupported characters" >&2
  exit 2
fi

mkdir -p "$(dirname "$log")" || exit 2
if ! (umask 077; set -o noclobber; : >"$log") 2>/dev/null; then
  echo "ERROR log path already exists or cannot be created: $log" >&2
  exit 2
fi

(
  echo "G3V verification-practices"
  echo "base_ref=$base_ref"
  julia --project=. tools/verify/mutation_check.jl
  mutation_status=$?
  julia --project=. tools/verify/ratchet_check.jl --base-ref "$base_ref"
  ratchet_status=$?
  echo "mutation_status=$mutation_status ratchet_status=$ratchet_status"
  if [[ $mutation_status -eq 0 && $ratchet_status -eq 0 ]]; then
    exit 0
  fi
  exit 1
) >>"$log" 2>&1
status=$?

if [[ $status -eq 0 ]]; then
  echo "PASS log=$log"
  grep -E 'PASS mutation=|base_sha=|PASS ratchet' "$log" || true
  exit 0
fi

echo "FAIL log=$log"
grep -nE 'FAIL|UNVERIFIED|ERROR' "$log" | head -20
exit 1
