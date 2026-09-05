#!/usr/bin/env bash
# G3C: run one complete Pkg.test() against an ephemeral commit in a sibling clone.
# The source repository's HEAD/index and .lake cache stay untouched; only the
# requested evidence log is written there.
set -u -o pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
repo_root="$(cd "$repo_root" && pwd -P)"
repo_parent="$(dirname "$repo_root")"
repo_name="$(basename "$repo_root")"
allow_full_lake_copy="${G3C_ALLOW_FULL_LAKE_COPY:-false}"

case "$allow_full_lake_copy" in
  true|false) ;;
  *)
    echo "ERROR G3C_ALLOW_FULL_LAKE_COPY must be true or false" >&2
    exit 2
    ;;
esac

write_basis_logs() {
  local manifest_path="$1"
  local output_path="$2"
  julia --startup-file=no -e '
using TOML
manifest = TOML.parsefile(ARGS[1])
for row in get(manifest, "contract", Any[])
    basis_log = String(get(row, "basis_log", ""))
    isempty(basis_log) && continue
    parts = split(basis_log, "/")
    startswith(basis_log, "logs/") || error("basis_log must be repository-relative under logs/: " * basis_log)
    all(part -> !isempty(part) && part != "." && part != "..", parts) ||
        error("basis_log contains a non-canonical path component: " * basis_log)
    (occursin("\n", basis_log) || occursin("\r", basis_log)) &&
        error("basis_log contains a line break")
    println(basis_log)
end
' "$manifest_path" >"$output_path"
}

write_path_dependencies() {
  local manifest_path="$1"
  local output_path="$2"
  julia --startup-file=no --project="$repo_root" -e '
using JSON3
manifest = JSON3.read(read(ARGS[1], String))
for package in manifest.packages
    String(package.type) == "path" || continue
    dependency = String(package.dir)
    startswith(dependency, "../") ||
        error("G3C supports only sibling path dependencies: " * dependency)
    name = dependency[4:end]
    occursin(r"^[A-Za-z0-9._-]+$", name) && name != "." && name != ".." ||
        error("G3C path dependency must have one canonical sibling component: " * dependency)
    println(dependency)
end
' "$manifest_path" >"$output_path"
}

write_input_projection() {
  local repository="$1"
  local commit="$2"
  local basis_logs="$3"
  local output_path="$4"
  local entry
  local relative_file

  git -C "$repository" ls-tree -rz --full-tree "$commit" |
    while IFS= read -r -d '' entry; do
      relative_file="${entry#*$'\t'}"
      case "$relative_file" in
        logs/*)
          grep -Fxq "$relative_file" "$basis_logs" || continue
          ;;
      esac
      printf '%s\0' "$entry"
    done >"$output_path"
}

write_included_untracked() {
  local repository="$1"
  local basis_logs="$2"
  local output_path="$3"
  local relative_file

  git -C "$repository" ls-files --others --exclude-standard -z |
    while IFS= read -r -d '' relative_file; do
      case "$relative_file" in
        logs/*)
          grep -Fxq "$relative_file" "$basis_logs" || continue
          ;;
      esac
      printf '%s\0' "$relative_file"
    done >"$output_path"
}

input_digest_for_commit() {
  local repository="$1"
  local commit="$2"
  local workspace="$3"
  local manifest_snapshot="$workspace/checker-semantic-manifest.toml"
  local basis_logs="$workspace/basis-logs.list"
  local projection="$workspace/input-projection.zlist"

  mkdir -p "$workspace" || return 2
  git -C "$repository" show "${commit}:specs/checker-semantic-manifest.toml" \
    >"$manifest_snapshot" || return 2
  write_basis_logs "$manifest_snapshot" "$basis_logs" || return 2
  write_input_projection "$repository" "$commit" "$basis_logs" "$projection" || return 2
  git -C "$repository" hash-object --stdin <"$projection"
}

cleanup_digest_workspace() {
  if [[ -z "${digest_workspace:-}" || ! -e "$digest_workspace" ]]; then
    return
  fi
  case "$digest_workspace" in
    "${TMPDIR:-/tmp}"/eriec-g3c-digest.*|/private/*/eriec-g3c-digest.*|/tmp/eriec-g3c-digest.*)
      rm -rf -- "$digest_workspace"
      ;;
    *)
      echo "ERROR refusing to remove unexpected digest workspace: $digest_workspace" >&2
      return 2
      ;;
  esac
}

if [[ "${1:-}" == "--print-input-digest" ||
      "${1:-}" == "--verify-input-digest" ]]; then
  digest_mode="$1"
  shift
  expected_digest=""
  if [[ "$digest_mode" == "--verify-input-digest" ]]; then
    expected_digest="${1:-}"
    shift || true
    if [[ ! "$expected_digest" =~ ^[0-9a-f]{40,64}$ ]]; then
      echo "ERROR expected digest must be 40 to 64 lowercase hexadecimal characters" >&2
      exit 2
    fi
  fi
  revision="${1:-HEAD}"
  if [[ "$revision" == -* || $# -gt 1 ]]; then
    echo "ERROR invalid revision or excess arguments" >&2
    exit 2
  fi
  commit="$(git -C "$repo_root" rev-parse --verify "${revision}^{commit}" 2>/dev/null)" || {
    echo "ERROR revision is not a commit: $revision" >&2
    exit 2
  }
  digest_workspace="$(mktemp -d "${TMPDIR:-/tmp}/eriec-g3c-digest.XXXXXX")" || exit 2
  trap cleanup_digest_workspace EXIT INT TERM
  actual_digest="$(input_digest_for_commit "$repo_root" "$commit" "$digest_workspace")" || exit 2
  object_format="$(git -C "$repo_root" rev-parse --show-object-format)" || exit 2
  echo "G3C_TEST_INPUT_REVISION=$commit"
  echo "G3C_TEST_INPUT_OBJECT_FORMAT=$object_format"
  echo "G3C_TEST_INPUT_DIGEST=$actual_digest"
  if [[ "$digest_mode" == "--verify-input-digest" ]]; then
    if [[ "$actual_digest" != "$expected_digest" ]]; then
      echo "FAIL G3C input digest expected=$expected_digest actual=$actual_digest"
      exit 1
    fi
    echo "PASS G3C input digest matches revision=$commit"
  fi
  exit 0
fi

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

sandbox_root=""
clone_root=""
metadata_root=""
lake_cache_mode="not_prepared"
path_dependency_origins=()
path_dependency_heads=()
path_dependency_index_trees=()
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
  path_dependency_git_state_mutated=false

  if [[ -n "$sandbox_root" && -e "$sandbox_root" ]]; then
    case "$sandbox_root" in
      "$repo_parent"/.bridge-protocol-g3c.*) rm -rf -- "$sandbox_root" || clone_destroyed=false ;;
      *) clone_destroyed=false ;;
    esac
  fi

  for dependency_index in "${!path_dependency_origins[@]}"; do
    dependency_origin="${path_dependency_origins[$dependency_index]}"
    dependency_head_after="$(git -C "$dependency_origin" rev-parse HEAD 2>/dev/null || echo unavailable)"
    dependency_index_after="$(git -C "$dependency_origin" write-tree 2>/dev/null || echo unavailable)"
    if [[ "$dependency_head_after" != "${path_dependency_heads[$dependency_index]}" ||
          "$dependency_index_after" != "${path_dependency_index_trees[$dependency_index]}" ]]; then
      path_dependency_git_state_mutated=true
    fi
  done
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
    echo "G3C_PATH_DEPENDENCY_HEAD_OR_INDEX_MUTATED=$path_dependency_git_state_mutated"
    echo "G3C_END"
  } >>"$log"

  if [[ "$clone_destroyed" != true || "$metadata_destroyed" != true ||
        "$origin_git_state_mutated" != false ||
        "$path_dependency_git_state_mutated" != false ]]; then
    echo "ERROR G3C cleanup or origin Git-state check failed log=$log" >&2
    exit 2
  fi
  exit "$result"
}
trap cleanup EXIT INT TERM

metadata_root="$(mktemp -d "${TMPDIR:-/tmp}/eriec-g3c-meta.XXXXXX")" || exit 2
sandbox_root="$(mktemp -d "$repo_parent/.bridge-protocol-g3c.XXXXXX")" || exit 2
clone_root="$sandbox_root/$repo_name"

remove_sandbox_path() {
  local target_path="$1"
  case "$target_path" in
    "$sandbox_root"/*)
      rm -rf -- "$target_path"
      ;;
    *)
      echo "ERROR refusing to remove path outside G3C sandbox: $target_path" >&2
      return 2
      ;;
  esac
}

validate_isolated_tree_symlinks() {
  local tree_root="$1"
  local link
  local resolved
  while IFS= read -r -d '' link; do
    resolved="$(realpath "$link")" || {
      echo "ERROR unresolved symlink in isolated tree: $link" >&2
      return 2
    }
    case "$resolved" in
      "$tree_root"/*) ;;
      *)
        echo "ERROR symlink escapes isolated tree: $link -> $resolved" >&2
        return 2
        ;;
    esac
  done < <(find "$tree_root" -type l -print0)
}

copy_tree_isolated() {
  local source_tree="$1"
  local target_tree="$2"
  local copy_errors="$metadata_root/lake-copy-errors.log"

  if [[ ! -d "$source_tree" || -L "$source_tree" || -e "$target_tree" ]]; then
    echo "ERROR isolated copy requires a real source directory and absent target" >&2
    return 2
  fi

  if cp -cR "$source_tree" "$target_tree" 2>>"$copy_errors"; then
    isolated_copy_mode="copy_on_write_macos"
  else
    remove_sandbox_path "$target_tree" || return 2
    if cp --reflink=always -a "$source_tree" "$target_tree" 2>>"$copy_errors"; then
      isolated_copy_mode="copy_on_write_gnu"
    else
      remove_sandbox_path "$target_tree" || return 2
      if [[ "$allow_full_lake_copy" != true ]]; then
        echo "ERROR copy-on-write cloning is unavailable; set G3C_ALLOW_FULL_LAKE_COPY=true for an isolated full copy" >&2
        sed -n '1,10p' "$copy_errors" >&2
        return 2
      fi
      cp -pR "$source_tree" "$target_tree" 2>>"$copy_errors" || return 2
      isolated_copy_mode="full_copy"
    fi
  fi
}

reset_isolated_lake_config() {
  local lake_root="$1"
  local config_path="$lake_root/config"
  case "$config_path" in
    "$sandbox_root"/*/.lake/config)
      rm -rf -- "$config_path" || return 2
      ;;
    *)
      echo "ERROR refusing to reset Lake config outside G3C sandbox: $config_path" >&2
      return 2
      ;;
  esac
}

prepare_isolated_lake() {
  local origin_lake="$1"
  local clone_lake="$2"

  if [[ ! -e "$origin_lake" ]]; then
    prepared_lake_cache_mode="fresh"
    return 0
  fi
  copy_tree_isolated "$origin_lake" "$clone_lake" || return 2
  prepared_lake_cache_mode="$isolated_copy_mode"

  [[ -d "$clone_lake" && ! -L "$clone_lake" ]] || {
    echo "ERROR clone .lake is not an isolated directory" >&2
    return 2
  }
  validate_isolated_tree_symlinks "$clone_lake" || return 2

  # Lake configuration caches absolute project paths. Rebuild them in the clone
  # so `lake env` cannot resolve the origin project cache through copied config.
  reset_isolated_lake_config "$clone_lake"
}

prepare_path_dependencies() {
  local dependency_relative
  local dependency_name
  local dependency_origin
  local dependency_clone
  local dependency_head
  local dependency_index_tree
  local dependency_cache_mode

  : >"$metadata_root/path-dependencies.log" || return 2
  while IFS= read -r dependency_relative; do
    [[ -n "$dependency_relative" ]] || continue
    dependency_name="${dependency_relative#../}"
    dependency_origin="$repo_parent/$dependency_name"
    dependency_clone="$sandbox_root/$dependency_name"
    if [[ ! -d "$dependency_origin" || -L "$dependency_origin" ||
          ! -d "$dependency_origin/.git" ]]; then
      echo "ERROR path dependency must be a real sibling Git repository: $dependency_origin" >&2
      return 2
    fi
    if [[ -n "$(git -C "$dependency_origin" status --porcelain=v1 --untracked-files=all)" ]]; then
      echo "ERROR path dependency worktree must be clean for isolated G3C: $dependency_origin" >&2
      return 2
    fi
    dependency_head="$(git -C "$dependency_origin" rev-parse HEAD)" || return 2
    dependency_index_tree="$(git -C "$dependency_origin" write-tree)" || return 2
    path_dependency_origins+=("$dependency_origin")
    path_dependency_heads+=("$dependency_head")
    path_dependency_index_trees+=("$dependency_index_tree")

    git clone --no-hardlinks --quiet "$dependency_origin" "$dependency_clone" || return 2
    validate_isolated_tree_symlinks "$dependency_clone" || return 2
    prepare_isolated_lake \
      "$dependency_origin/.lake" \
      "$dependency_clone/.lake" || return 2
    dependency_cache_mode="$prepared_lake_cache_mode"
    printf 'path=%s origin=%s head=%s index_tree=%s cache_mode=%s shared_mutable=false\n' \
      "$dependency_relative" \
      "$dependency_origin" \
      "$dependency_head" \
      "$dependency_index_tree" \
      "$dependency_cache_mode" \
      >>"$metadata_root/path-dependencies.log"
  done <"$metadata_root/path-dependencies.list"
}

git -C "$repo_root" diff --binary HEAD >"$metadata_root/tracked.patch" || exit 2
write_basis_logs \
  "$repo_root/specs/checker-semantic-manifest.toml" \
  "$metadata_root/basis-logs.list" || exit 2
write_included_untracked \
  "$repo_root" \
  "$metadata_root/basis-logs.list" \
  "$metadata_root/untracked.zlist" || exit 2
write_path_dependencies \
  "$repo_root/lake-manifest.json" \
  "$metadata_root/path-dependencies.list" || exit 2
prepare_path_dependencies || exit 2
git clone --no-hardlinks --quiet "$repo_root" "$clone_root" || exit 2

if [[ -s "$metadata_root/tracked.patch" ]]; then
  git -C "$clone_root" apply --index --binary "$metadata_root/tracked.patch" || exit 2
fi

while IFS= read -r -d '' relative_file; do
  mkdir -p "$clone_root/$(dirname "$relative_file")" || exit 2
  cp -pP "$repo_root/$relative_file" "$clone_root/$relative_file" || exit 2
  git -C "$clone_root" add -- "$relative_file" || exit 2
done <"$metadata_root/untracked.zlist"

git -C "$clone_root" \
  -c user.name="ERIEC G3C Runner" \
  -c user.email="g3c@invalid.local" \
  commit --quiet -m "ephemeral G3C verification snapshot" || exit 2
ephemeral_commit="$(git -C "$clone_root" rev-parse HEAD)" || exit 2
ephemeral_tree="$(git -C "$clone_root" rev-parse "${ephemeral_commit}^{tree}")" || exit 2

git -C "$repo_root" diff --binary HEAD >"$metadata_root/tracked-after.patch" || exit 2
write_included_untracked \
  "$repo_root" \
  "$metadata_root/basis-logs.list" \
  "$metadata_root/untracked-after.zlist" || exit 2
cmp -s "$metadata_root/tracked.patch" "$metadata_root/tracked-after.patch" || {
  echo "ERROR tracked worktree changed while G3C captured its snapshot" >&2
  exit 2
}
cmp -s "$metadata_root/untracked.zlist" "$metadata_root/untracked-after.zlist" || {
  echo "ERROR included untracked inventory changed while G3C captured its snapshot" >&2
  exit 2
}
while IFS= read -r -d '' relative_file; do
  cmp -s "$repo_root/$relative_file" "$clone_root/$relative_file" || {
    echo "ERROR included untracked file changed while G3C captured it: $relative_file" >&2
    exit 2
  }
done <"$metadata_root/untracked.zlist"

input_digest="$(input_digest_for_commit \
  "$clone_root" \
  "$ephemeral_commit" \
  "$metadata_root/ephemeral-digest")" || exit 2
input_object_format="$(git -C "$clone_root" rev-parse --show-object-format)" || exit 2

prepare_isolated_lake "$repo_root/.lake" "$clone_root/.lake" || exit 2
lake_cache_mode="$prepared_lake_cache_mode"

{
  echo "G3C_PROVENANCE_VERSION=2"
  echo "G3C_EXECUTION=single Pkg.test() in sibling clone at ephemeral commit"
  echo "G3C_EPHEMERAL_COMMIT=$ephemeral_commit"
  echo "G3C_EPHEMERAL_TREE=$ephemeral_tree"
  echo "G3C_TEST_INPUT_POLICY=exclude logs/** except semantic-manifest basis_log dependencies"
  echo "G3C_TEST_INPUT_OBJECT_FORMAT=$input_object_format"
  echo "G3C_TEST_INPUT_DIGEST=$input_digest"
  echo "G3C_ORIGIN_HEAD=$origin_head"
  echo "G3C_ORIGIN_INDEX_TREE=$origin_index_tree"
  echo "G3C_ORIGIN_WORKTREE_DIRTY=$origin_dirty"
  echo "G3C_ORIGIN_REPOSITORY=$repo_root"
  echo "G3C_SANDBOX=$sandbox_root"
  echo "G3C_CLONE=$clone_root"
  echo "G3C_SOURCE_CAPTURE_STABLE=true"
  echo "G3C_LAKE_CACHE_MODE=$lake_cache_mode"
  echo "G3C_LAKE_SHARED_MUTABLE=false"
  echo "G3C_PATH_DEPENDENCIES_BEGIN"
  cat "$metadata_root/path-dependencies.log"
  echo "G3C_PATH_DEPENDENCIES_END"
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
