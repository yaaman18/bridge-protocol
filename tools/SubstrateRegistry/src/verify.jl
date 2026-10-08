# verify_substrate_registration (RSB-001 §5, §7).

# The fixed remote is a literal of the validator, never a registry value or local setting.
const FIXED_REMOTE_URL = "https://github.com/yaaman18/bridge-protocol.git"
const FIXED_REMOTE_REF = "refs/heads/main"
const REGISTRY_PATH = "specs/substrate-registry.toml"
const RUNNER_MANIFEST_PATH = "Manifest.toml"

"""Verification outcome that is not a registration. `status` is `:FAILED` when a checked
condition is false and `:UNVERIFIED` when the remote could not be consulted."""
struct RegistrationRejected
    status::Symbol
    code::Symbol
    detail::String
end

struct _Witness end

"""Capability produced only by a successful verification (RSB-001 §5). The constructor needs
an internal witness; this keeps the supported runner API honest but is not a security
boundary against arbitrary Julia code."""
struct VerifiedRegistration
    registration_id::String
    registration_commit::String
    profile_commit::String
    profile_path::String
    analysis_plan_path::String
    profile_blob_sha256::String
    analysis_plan_digest::String
    profile_id::String
    remote_url::String
    remote_ref::String
    observed_remote_oid::String
    profile_schema_validation_version::String
    analysis_schema_validation_version::String
    author_declared_at::String
    author_declared_at_semantics::String
    preregistration_strength::String
    case_ids::Vector{String}
    runner::Dict{String,Any}
    VerifiedRegistration(::_Witness, args...) = new(args...)
end

_reject(code::Symbol, detail::AbstractString) = RegistrationRejected(:FAILED, code, String(detail))
_unverified(code::Symbol, detail::AbstractString) = RegistrationRejected(:UNVERIFIED, code, String(detail))

_sha(bytes) = bytes2hex(sha256(bytes))

"""State of the runner checkout recorded at run start and re-checked at completion."""
function runner_state(runner_repo::String)
    head = _git(["rev-parse", "--verify", "HEAD^{commit}"]; dir=runner_repo)
    tree = _git(["rev-parse", "--verify", "HEAD^{tree}"]; dir=runner_repo)
    status = _git(["status", "--porcelain=v1", "--untracked-files=all"]; dir=runner_repo)
    (head.ok && tree.ok && status.ok) || error("runner checkout is not a readable git work tree")
    tracked = _git(["ls-files", "--error-unmatch", "--", RUNNER_MANIFEST_PATH]; dir=runner_repo)
    manifest = joinpath(runner_repo, RUNNER_MANIFEST_PATH)
    Dict{String,Any}(
        "runner_commit" => _text(head),
        "runner_tree" => _text(tree),
        "runner_dirty" => !isempty(status.out),
        "manifest_tracked" => tracked.ok,
        "manifest_sha256" => isfile(manifest) ? _sha(read(manifest)) : "",
        "julia_version" => string(VERSION),
    )
end

"""
    verify_substrate_registration(registration_commit; registration_id, runner_repo,
        expected_profile_blob_sha256=nothing, expected_analysis_plan_digest=nothing)

Returns a `VerifiedRegistration` or a `RegistrationRejected`. The authority is the registry
row at `registration_commit` on the fixed remote; caller-supplied expectations are only
compared against that row.
"""
verify_substrate_registration(registration_commit::AbstractString;
        registration_id::AbstractString, runner_repo::AbstractString,
        expected_profile_blob_sha256=nothing, expected_analysis_plan_digest=nothing) =
    _verify(registration_commit; registration_id, runner_repo,
        remote_url=FIXED_REMOTE_URL, remote_ref=FIXED_REMOTE_REF,
        expected_profile_blob_sha256, expected_analysis_plan_digest)

function _verify(commit::AbstractString; registration_id::AbstractString,
        runner_repo::AbstractString, remote_url::String, remote_ref::String,
        expected_profile_blob_sha256=nothing, expected_analysis_plan_digest=nothing)
    registration_commit = String(commit)
    occursin(r"^[0-9a-f]{40}\z", registration_commit) ||
        return _reject(:BAD_REGISTRATION_COMMIT, "registration_commit must be a full lowercase SHA-1")
    mktempdir() do workdir
        _verify_in(workdir, registration_commit, String(registration_id), String(runner_repo),
            remote_url, remote_ref, expected_profile_blob_sha256, expected_analysis_plan_digest)
    end
end

function _observe_remote(workdir::String, url::String, ref::String)
    # Both remote operations run inside a fresh bare repository, so no repository-local
    # configuration of the caller's working directory applies.
    bare = joinpath(workdir, "observed.git")
    _git(["init", "--bare", "--quiet", bare]).ok || error("cannot create temporary repository")
    ls = _git(["ls-remote", "--", url, ref]; dir=bare)
    ls.ok || return _unverified(:REMOTE_UNREACHABLE, "ls-remote failed: $(strip(ls.err))")
    listed = nothing
    for line in split(String(copy(ls.out)), '\n'; keepempty=false)
        oid, name = split(line, '\t'; limit=2)
        name == ref && (listed = String(oid))
    end
    listed === nothing && return _reject(:REMOTE_WRONG_REF, "ref $ref does not exist on the remote")
    fetch = _git(["fetch", "--no-tags", "--quiet", "--", url, "+$ref:refs/rsb/observed"]; dir=bare)
    fetch.ok || return _unverified(:REMOTE_UNREACHABLE, "fetch failed: $(strip(fetch.err))")
    observed = _text(_git(["rev-parse", "--verify", "refs/rsb/observed^{commit}"]; dir=bare))
    observed == listed ||
        return _unverified(:REMOTE_REF_MOVED, "ref moved between ls-remote and fetch")
    (bare, String(observed))
end

function _regular_blob(repo, commit, path)
    entry = _tree_entry(repo, commit, path)
    entry === nothing && return nothing
    mode, oid = entry
    mode == "100644" || return :not_regular
    _blob_bytes(repo, oid)
end

function _verify_in(workdir, registration_commit, registration_id, runner_repo,
        remote_url, remote_ref, expected_profile, expected_analysis)
    observed = _observe_remote(workdir, remote_url, remote_ref)
    observed isa RegistrationRejected && return observed
    repo, observed_oid = observed

    # (v) registration_commit is reachable from the fixed ref.
    (_has_commit(repo, registration_commit) &&
        _is_ancestor(repo, registration_commit, observed_oid)) ||
        return _reject(:REMOTE_REG_UNREACHABLE, "registration_commit is not reachable from $remote_ref")

    # The registry row at registration_commit is the authority.
    registry = _read_registry(repo, registration_commit, remote_url, remote_ref)
    registry isa RegistrationRejected && return registry
    row = _row(registry, registration_id)
    row === nothing && return _reject(:UNREGISTERED, "no registry row for $(repr(registration_id))")

    # The registry at the observed tip may only have grown: the row must be unchanged and
    # must not be withdrawn there.
    latest = _read_registry(repo, observed_oid, remote_url, remote_ref)
    latest isa RegistrationRejected &&
        return _reject(latest.code, "at the observed tip: " * latest.detail)
    _row(latest, registration_id) == row ||
        return _reject(:REGISTRY_ROW_EDITED, "the registry row differs at the observed tip")
    any(w -> w["registration_id"] == registration_id, latest["withdrawal"]) &&
        return _reject(:WITHDRAWN, "registration $(repr(registration_id)) is withdrawn at the observed tip")
    strength = _preregistration_strength(latest, registration_id)
    ppath, apath = row["profile_path"], row["analysis_plan_path"]

    # (i)(ii) both blobs exist at registration_commit and match the registered digests.
    reg_profile = _regular_blob(repo, registration_commit, ppath)
    reg_analysis = _regular_blob(repo, registration_commit, apath)
    (reg_profile isa AbstractVector{UInt8} && reg_analysis isa AbstractVector{UInt8}) ||
        return _reject(:REG_BLOB_MISSING, "registered paths are not regular blobs at registration_commit")
    (_sha(reg_profile) == row["profile_blob_sha256"] &&
        _sha(reg_analysis) == row["analysis_plan_digest"]) ||
        return _reject(:REMOTE_REG_BLOB_MISMATCH, "blobs at registration_commit differ from the registered digests")

    # (vi) registration_commit descends from profile_commit.
    pcommit = row["profile_commit"]
    (_has_commit(repo, pcommit) && _is_ancestor(repo, pcommit, registration_commit)) ||
        return _reject(:REMOTE_NOT_DESCENDANT, "registration_commit does not descend from profile_commit")

    # (iii) profile_commit carries the same paths with the same raw bytes.
    p_profile = _regular_blob(repo, pcommit, ppath)
    p_analysis = _regular_blob(repo, pcommit, apath)
    (p_profile == reg_profile && p_analysis == reg_analysis) ||
        return _reject(:REMOTE_PROFILE_BLOB_MISMATCH, "profile_commit does not carry the registered bytes")

    # (iv) no commit on an ancestry path from profile_commit to registration_commit changes
    # those bytes. Side branches merged in without descending from profile_commit are not on
    # such a path; if they change the files, the merge commit itself carries the change.
    between = _git(["rev-list", "--ancestry-path", "$pcommit..$registration_commit"]; dir=repo)
    between.ok || error("rev-list failed: $(between.err)")
    for c in split(String(copy(between.out)), '\n'; keepempty=false)
        c = String(c)
        (_regular_blob(repo, c, ppath) == reg_profile &&
            _regular_blob(repo, c, apath) == reg_analysis) ||
            return _reject(:PATHS_CHANGED, "registered bytes change at commit $c")
    end

    # Exact schemas; only a successful validation may yield a registration (RSB-001 §3).
    aversion = row["analysis_schema_validation_version"]
    profile, analysis = try
        p = validate_profile(reg_profile; version=row["profile_schema_validation_version"])
        a = validate_analysis_plan(reg_analysis; version=aversion)
        validate_pair(p, a)
        (p, a)
    catch e
        e isa SchemaViolation || rethrow()
        return _reject(:SCHEMA, join(e.errors, "; "))
    end

    # v2: each criterion package is bound by its directory tree (RSB-PLAN-002 §3.2). The tree at
    # profile_commit must carry the registered OID, and no commit on an ancestry path from
    # profile_commit to registration_commit may change it.
    if aversion == ANALYSIS_SCHEMA_V2
        path_commits = [pcommit; [String(c) for c in split(String(copy(between.out)), '\n'; keepempty=false)]]
        for b in analysis["criterion_binding"]
            path, oid = b["package_path"], b["package_tree_oid"]
            tree_oid_at(repo, pcommit, path) == oid ||
                return _reject(:BINDING_TREE_MISMATCH,
                    "criterion $(b["criterion_id"]): tree of $path at profile_commit differs from the registered OID")
            for c in path_commits
                tree_oid_at(repo, c, path) == oid ||
                    return _reject(:BINDING_TREE_CHANGED,
                        "criterion $(b["criterion_id"]): tree of $path changes at commit $c")
            end
        end
    end

    # Caller expectations are checked against the row, never used as the authority.
    expected_profile === nothing || expected_profile == row["profile_blob_sha256"] ||
        return _reject(:CALLER_EXPECTATION_MISMATCH, "expected profile digest differs from the registry row")
    expected_analysis === nothing || expected_analysis == row["analysis_plan_digest"] ||
        return _reject(:CALLER_EXPECTATION_MISMATCH, "expected analysis digest differs from the registry row")

    # The runner must be clean and must read exactly the registered bytes.
    runner = runner_state(runner_repo)
    runner["runner_dirty"] && return _reject(:RUNNER_DIRTY, "runner checkout has uncommitted or untracked changes")
    runner["manifest_tracked"] || return _reject(:RUNNER_MANIFEST, "runner Manifest.toml is not tracked")
    delete!(runner, "manifest_tracked")
    run_profile = joinpath(runner_repo, ppath)
    run_analysis = joinpath(runner_repo, apath)
    (isfile(run_profile) && _sha(read(run_profile)) == row["profile_blob_sha256"]) ||
        return _reject(:RUNNER_PROFILE_MISMATCH, "runner profile bytes differ from the registered digest")
    (isfile(run_analysis) && _sha(read(run_analysis)) == row["analysis_plan_digest"]) ||
        return _reject(:RUNNER_ANALYSIS_MISMATCH, "runner analysis plan bytes differ from the registered digest")

    VerifiedRegistration(_Witness(),
        registration_id, registration_commit, pcommit, ppath, apath,
        row["profile_blob_sha256"], row["analysis_plan_digest"], profile["profile_id"],
        remote_url, remote_ref, observed_oid,
        row["profile_schema_validation_version"], aversion,
        row["author_declared_at"], row["author_declared_at_semantics"], strength,
        canonical_case_ids(profile), runner)
end

function _read_registry(repo, commit, remote_url, remote_ref)
    bytes = _regular_blob(repo, commit, REGISTRY_PATH)
    bytes isa AbstractVector{UInt8} ||
        return _reject(:REGISTRY_MISSING, "$REGISTRY_PATH is not a regular blob at $commit")
    try
        validate_registry(bytes; remote_url, remote_ref)
    catch e
        e isa SchemaViolation || rethrow()
        _reject(:REGISTRY_SCHEMA, join(e.errors, "; "))
    end
end

function _row(registry, registration_id)
    rows = [r for r in registry["registration"] if r["registration_id"] == registration_id]
    length(rows) == 1 ? only(rows) : nothing
end

"""`"full"`, or `"post_results_replacement"` when any registration this one replaces
(directly or through a chain) was withdrawn after its results were seen."""
function _preregistration_strength(registry, registration_id)
    withdrawals = Dict(w["registration_id"] => w for w in registry["withdrawal"])
    seen = Set{String}()
    id = registration_id
    while true
        prev = _row(registry, id)["supersedes"]
        (isempty(prev) || prev in seen) && return "full"
        push!(seen, prev)
        withdrawals[prev]["results_seen_before_withdrawal"] && return "post_results_replacement"
        id = prev
    end
end
