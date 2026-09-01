#!/usr/bin/env bash
# G3C: run one complete Pkg.test() against an ephemeral commit in a sibling clone.
# The source repository is never committed or otherwise mutated by this script.
set -u -o pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
repo_root="$(cd "$repo_root" && pwd -P)"
repo_parent="$(dirname "$repo_root")"
log_arg="${1:-}"

if [[ -n "$log_arg" ]]; then
  if [[ "$log_arg" = /* ]]; then
    log="$log_arg"
  else
    log="$repo_root/$log_arg"
  fi
  mkdir -p "$(dirname "$log")" || exit 2
  log_dir="$(cd "$(dirname "$log")" && pwd -P)" || exit 2
  log="$log_dir/$(basename "$log")"
  if ! (umask 077; set -o noclobber; : >"$log") 2>/dev/null; then
    echo "ERROR log path already exists or cannot be created: $log" >&2
    exit 2
  fi
else
  log_dir="$repo_root/logs/gates/quiet"
  mkdir -p "$log_dir" || exit 2
  if ! log="$(mktemp "$log_dir/G3C-$(date +%Y%m%d-%H%M%S)-$$.log.XXXXXX")"; then
    echo "ERROR could not create a unique log in: $log_dir" >&2
    exit 2
  fi
fi

clone_root=""
metadata_root=""
origin_head="$(git -C "$repo_root" rev-parse HEAD)" || exit 2
origin_index_tree="$(git -C "$repo_root" write-tree)" || exit 2
origin_status="$(git -C "$repo_root" status --porcelain=v1 --untracked-files=all)" || exit 2
origin_dirty=false
[[ -n "$origin_status" ]] && origin_dirty=true

cleanup() {
  result=$?
  trap - EXIT INT TERM
  clone_destroyed=true
  metadata_destroyed=true
  origin_git_state_mutated=false

  if [[ -n "$clone_root" && -e "$clone_root" ]]; then
    case "$clone_root" in
      "$repo_parent"/.bridge-protocol-g3c.*) rm -rf -- "$clone_root" || clone_destroyed=false ;;
      *) clone_destroyed=false ;;
    esac
  fi
  if [[ -n "$metadata_root" && -e "$metadata_root" ]]; then
    case "$metadata_root" in
      "${TMPDIR:-/tmp}"/eriec-g3c-meta.*|/private/*/eriec-g3c-meta.*|/tmp/eriec-g3c-meta.*)
        rm -rf -- "$metadata_root" || metadata_destroyed=false
        ;;
      *) metadata_destroyed=false ;;
    esac
  fi

  final_origin_head="$(git -C "$repo_root" rev-parse HEAD 2>/dev/null || echo unavailable)"
  final_origin_index_tree="$(git -C "$repo_root" write-tree 2>/dev/null || echo unavailable)"
  if [[ "$final_origin_head" != "$origin_head" ||
        "$final_origin_index_tree" != "$origin_index_tree" ]]; then
    origin_git_state_mutated=true
  fi

  {
    echo "G3C_CLONE_DESTROYED=$clone_destroyed"
    echo "G3C_METADATA_DESTROYED=$metadata_destroyed"
    echo "G3C_ORIGIN_HEAD_AFTER=$final_origin_head"
    echo "G3C_ORIGIN_INDEX_TREE_AFTER=$final_origin_index_tree"
    echo "G3C_ORIGIN_HEAD_OR_INDEX_MUTATED=$origin_git_state_mutated"
    echo "G3C_END"
  } >>"$log"

  if [[ "$clone_destroyed" != true || "$metadata_destroyed" != true ||
        "$origin_git_state_mutated" != false ]]; then
    echo "ERROR G3C cleanup or origin Git-state check failed log=$log" >&2
    exit 2
  fi
  exit "$result"
}
trap cleanup EXIT INT TERM

metadata_root="$(mktemp -d "${TMPDIR:-/tmp}/eriec-g3c-meta.XXXXXX")" || exit 2
clone_root="$(mktemp -d "$repo_parent/.bridge-protocol-g3c.XXXXXX")" || exit 2
rmdir "$clone_root" || exit 2

git -C "$repo_root" diff --binary HEAD >"$metadata_root/tracked.patch" || exit 2
git -C "$repo_root" ls-files --others --exclude-standard -z >"$metadata_root/untracked.zlist" || exit 2
julia --startup-file=no -e '
using TOML
manifest = TOML.parsefile(ARGS[1])
for row in get(manifest, "contract", Any[])
    basis_log = String(get(row, "basis_log", ""))
    isempty(basis_log) || println(basis_log)
end
' "$repo_root/specs/checker-semantic-manifest.toml" >"$metadata_root/basis-logs.list" || exit 2
git clone --no-hardlinks --quiet "$repo_root" "$clone_root" || exit 2

if [[ -s "$metadata_root/tracked.patch" ]]; then
  git -C "$clone_root" apply --index --binary "$metadata_root/tracked.patch" || exit 2
fi

while IFS= read -r -d '' relative_file; do
  case "$relative_file" in
    logs/*)
      grep -Fxq "$relative_file" "$metadata_root/basis-logs.list" || continue
      ;;
  esac
  mkdir -p "$clone_root/$(dirname "$relative_file")" || exit 2
  cp -pP "$repo_root/$relative_file" "$clone_root/$relative_file" || exit 2
  git -C "$clone_root" add -- "$relative_file" || exit 2
done <"$metadata_root/untracked.zlist"

git -C "$clone_root" \
  -c user.name="ERIEC G3C Runner" \
  -c user.email="g3c@invalid.local" \
  commit --quiet -m "ephemeral G3C verification snapshot" || exit 2
ephemeral_commit="$(git -C "$clone_root" rev-parse HEAD)" || exit 2

if [[ -d "$repo_root/.lake" && ! -e "$clone_root/.lake" ]]; then
  ln -s "$repo_root/.lake" "$clone_root/.lake" || exit 2
fi

{
  echo "G3C_PROVENANCE_VERSION=1"
  echo "G3C_EXECUTION=single Pkg.test() in sibling clone at ephemeral commit"
  echo "G3C_EPHEMERAL_COMMIT=$ephemeral_commit"
  echo "G3C_ORIGIN_HEAD=$origin_head"
  echo "G3C_ORIGIN_INDEX_TREE=$origin_index_tree"
  echo "G3C_ORIGIN_WORKTREE_DIRTY=$origin_dirty"
  echo "G3C_ORIGIN_REPOSITORY=$repo_root"
  echo "G3C_CLONE=$clone_root"
  echo "G3C_LOG_POLICY=exclude logs/** except semantic-manifest basis_log dependencies"
  echo "G3C_INCLUDED_CHANGES_BEGIN"
  git -C "$clone_root" diff-tree --no-commit-id --name-status -r "$ephemeral_commit"
  echo "G3C_INCLUDED_CHANGES_END"
  echo "G3C_TEST_COMMAND=julia --project=. -e 'using Pkg; Pkg.test()'"
  echo "G3C_TEST_OUTPUT_BEGIN"
} >>"$log"

cd "$clone_root" || exit 2
if julia --project=. -e 'using Pkg; Pkg.test()' >>"$log" 2>&1; then
  {
    echo "G3C_TEST_OUTPUT_END"
    echo "G3C_RESULT=PASS"
  } >>"$log"
  echo "PASS G3C ephemeral_commit=$ephemeral_commit origin_head=$origin_head log=$log"
  grep -A2 "Test Summary" "$log" | tail -6 || true
  exit 0
else
  test_status=$?
  {
    echo "G3C_TEST_OUTPUT_END"
    echo "G3C_RESULT=FAIL"
    echo "G3C_TEST_EXIT=$test_status"
  } >>"$log"
  echo "FAIL G3C ephemeral_commit=$ephemeral_commit origin_head=$origin_head log=$log"
  grep -nE "Error During Test|Test Failed|ERROR:|LoadError" "$log" | head -20
  exit "$test_status"
fi
