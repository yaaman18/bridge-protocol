# RSB-001 tests. Run in isolation:
#   JULIA_LOAD_PATH=@:@stdlib julia --startup-file=no --project=tools/SubstrateRegistry \
#       tools/SubstrateRegistry/test/runtests.jl
# Fixtures are synthetic (RSB-001 §11): the scratch profile below is not the candidate substrate,
# and its profile_id contains `scratch`. All remotes are local bare repositories.

using Test
using SHA
using TOML
using SubstrateRegistry
const SR = SubstrateRegistry

const PROJECT_DIR = normpath(joinpath(@__DIR__, ".."))

const SCRATCH_PROFILE = """
# synthetic fixture, not a candidate
schema_version = 3
profile_id = "scratch-fixture-01"
protocol_version = "scratch-protocol"
digest_format = "sha256_file_bytes"

[substrate]
unit_count = 4
units = ["u0", "u1", "u2", "u3"]
input_units = ["u0"]
output_units = ["u3"]
internal_units = ["u1", "u2"]
require_disjoint_io = true
state_values = [0, 1]
arithmetic = "checked_int64"
weight_sum_bound = 8
thresholds = [1, 1, 1, 1]
weights = [[0, 1, 1], [1, 2, 1], [2, 1, 1], [2, 3, 1]]
environment_map = [[3, 0, 1]]
update_rule = "synchronous_old_state_sum_ge_threshold"
ordinary_edges_to_input = "forbidden"
exogenous_drive = "none"
self_edges = "forbidden"
duplicate_edges = "reject"
zero_weight_edges = "reject"

[observation]
kappa_rule = "persistent_active"
kappa_transitions = 2
state_window_points = 3
preparation_steps = 2
intervention_horizon_steps = 3
effect_window_points = 2
epsilon_rule = "active_inputs_at_branch_snapshot"
boundary_rule = "outgoing_nonzero_edges"
boundary_edge_sources = ["weights", "environment_map"]
initial_history = "none"
persistence_only = true
carrier = "units"

[measurement]
intervention_rule = "r"
intervention_scope = "r"
intervention_subsets = "r"
alpha_rule = "r"
sigma_rule = "r"
pi_rule = "r"
rho_rule = "r"
direct_self_effect = "r"
coalition_rule = "r"
coalition_projection_to_unary_relations = "forbidden"
relation_scope = "r"
trial_sharing = "r"
relation_aggregation = "none"

[enumeration]
policy = "exhaustive"
bit_order = "unit_index_is_lsb_index"
case_order = "ascending_integer"
case_count = 16
early_success_stop = false

[output]
record_all_cases = true
phenomenal_claim = "not_certified"
"""

const SCRATCH_ANALYSIS = """
analysis_schema_version = 1
profile_id = "scratch-fixture-01"
analysis_plan_id = "scratch-analysis-01"

[interpretation]
zero_pass_count = "valid_result"
nonempty_flags = "derived_diagnostics"
non_dc_interpretation = "supplied_unary_relations_not_certified"
claim_scope = "finite_horizon_signal_contribution"
primary_criterion = "dc"
post_results_replacement = "not_preregistered_evidence"
recorded_criteria = ["dc", "dc2"]
dc2_sigma_cover_cases = "recorded_not_counted_as_hinge_evidence"

[incomplete_runs]
missing_case = "run_incomplete"
duplicate_case = "run_invalid"

[decisions]
retraction_conditions = ["scratch"]
stop_conditions = ["scratch"]
forbidden_adjustments = ["tune_parameters_after_pass_rate"]

[[falsification]]
id = "SCRATCH-1"
condition = "scratch"
expected = "scratch"
"""

const PROFILE_PATH = "specs/reactivation-substrate-v1.toml"
const ANALYSIS_PATH = "specs/reactivation-analysis-plan-v1.toml"

sha(s::AbstractString) = bytes2hex(sha256(Vector{UInt8}(s)))
sha(b::AbstractVector{UInt8}) = bytes2hex(sha256(b))

function git(dir, args...)
    cmd = `git -C $dir -c user.name=fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false $(collect(String, args))`
    env = Dict{String,String}(k => v for (k, v) in ENV if !startswith(k, "GIT_"))
    env["GIT_CONFIG_NOSYSTEM"] = "1"
    env["GIT_CONFIG_GLOBAL"] = "/dev/null"
    strip(read(setenv(cmd, env), String))
end

function write_file(repo, path, content)
    full = joinpath(repo, path)
    mkpath(dirname(full))
    write(full, content)
end

function commit_all(repo, message)
    git(repo, "add", "-A")
    git(repo, "commit", "-q", "--allow-empty", "-m", message)
    git(repo, "rev-parse", "HEAD")
end

registry_toml(rows; withdrawals=String[]) = "registry_schema_version = 1\n" *
    (isempty(withdrawals) ? "withdrawal = []\n" : "") * join(rows, "") * join(withdrawals, "")

function withdrawal_row(id; superseded_by="", seen=false)
    """

    [[withdrawal]]
    registration_id = "$id"
    reason = "scratch"
    superseded_by = "$superseded_by"
    results_seen_before_withdrawal = $seen
    declared_at = "2026-09-28T00:00:00Z"
    declared_at_semantics = "self_declared_not_used_for_ordering"
    """
end

function registry_row(; id="scratch-reg-01", profile_commit, remote, ref="refs/heads/main",
        profile=SCRATCH_PROFILE, analysis=SCRATCH_ANALYSIS, supersedes="")
    """

    [[registration]]
    registration_id = "$id"
    profile_path = "$PROFILE_PATH"
    analysis_plan_path = "$ANALYSIS_PATH"
    profile_blob_sha256 = "$(sha(profile))"
    analysis_plan_digest = "$(sha(analysis))"
    profile_commit = "$profile_commit"
    remote_url = "$remote"
    remote_ref = "$ref"
    profile_schema_validation_version = "rsb-profile-schema-v1"
    analysis_schema_validation_version = "rsb-analysis-schema-v1"
    author_declared_at = "2026-09-27T00:00:00Z"
    author_declared_at_semantics = "self_declared_not_used_for_ordering"
    supersedes = "$supersedes"
    """
end

function new_work(root)
    work = joinpath(root, "work")
    mkpath(work)
    git(work, "init", "-q", "-b", "main")
    write_file(work, "Manifest.toml", "# fixture manifest\n")
    work
end

function publish(root, work)
    bare = joinpath(root, "remote.git")
    git(root, "clone", "-q", "--bare", work, bare)
    runner = joinpath(root, "runner")
    git(root, "clone", "-q", bare, runner)
    bare, runner
end

"""Valid baseline: P adds the two files, R adds the registry row on top of P."""
function baseline(root; profile=SCRATCH_PROFILE, analysis=SCRATCH_ANALYSIS)
    work = new_work(root)
    write_file(work, PROFILE_PATH, profile)
    write_file(work, ANALYSIS_PATH, analysis)
    P = commit_all(work, "profile")
    bare = joinpath(root, "remote.git")
    write_file(work, "specs/substrate-registry.toml",
        registry_toml([registry_row(; profile_commit=P, remote=bare, profile, analysis)]))
    R = commit_all(work, "registration")
    _, runner = publish(root, work)
    (; work, bare, runner, P, R)
end

verify(f; kwargs...) = SR._verify(f.R; registration_id="scratch-reg-01", runner_repo=f.runner,
    remote_url=f.bare, remote_ref="refs/heads/main", kwargs...)

rejected(result, code) = result isa SR.RegistrationRejected && result.code === code

@testset "RSB-001 substrate registry" begin
    @testset "isolation from ERIEC (§8)" begin
        @test Base.find_package("ERIEC") === nothing
        project = TOML.parsefile(joinpath(PROJECT_DIR, "Project.toml"))
        @test sort!(collect(keys(project["deps"]))) == ["SHA", "TOML"]
        src = joinpath(PROJECT_DIR, "src")
        @test sort!(readdir(src)) ==
            ["SubstrateRegistry.jl", "cases.jl", "cli.jl", "git.jl", "records.jl", "schema.jl", "verify.jl"]
        includes = String[]
        for file in readdir(src; join=true), m in eachmatch(r"include\(\"([^\"]+)\"\)", read(file, String))
            push!(includes, m.captures[1])
        end
        @test sort!(includes) == ["cases.jl", "cli.jl", "git.jl", "records.jl", "schema.jl", "verify.jl"]
        for file in readdir(src; join=true)
            for line in eachline(file)
                occursin(r"^\s*(using|import)\s", line) || continue
                @test occursin(r"^\s*(using|import)\s+(SHA|TOML)\s*$", line)
            end
        end
    end

    @testset "schemas" begin
        p = SR.validate_profile(Vector{UInt8}(SCRATCH_PROFILE))
        a = SR.validate_analysis_plan(Vector{UInt8}(SCRATCH_ANALYSIS))
        @test SR.validate_pair(p, a)
        @test_throws SR.SchemaViolation SR.validate_profile(Vector{UInt8}("not = [toml"))
        bad_edges = replace(SCRATCH_PROFILE, "[2, 3, 1]]" => "[2, 3, 1], [1, 1, 1]]")
        @test_throws SR.SchemaViolation SR.validate_profile(Vector{UInt8}(bad_edges))
        into_input = replace(SCRATCH_PROFILE, "[2, 3, 1]]" => "[2, 3, 1], [1, 0, 1]]")
        @test_throws SR.SchemaViolation SR.validate_profile(Vector{UInt8}(into_input))
        promoted = replace(SCRATCH_PROFILE, "phenomenal_claim = \"not_certified\"" => "phenomenal_claim = \"certified\"")
        @test_throws SR.SchemaViolation SR.validate_profile(Vector{UInt8}(promoted))
        negative = replace(SCRATCH_PROFILE, "unit_count = 4" => "unit_count = -1")
        @test_throws SR.SchemaViolation SR.validate_profile(Vector{UInt8}(negative))
        other_id = replace(SCRATCH_ANALYSIS, "profile_id = \"scratch-fixture-01\"" => "profile_id = \"scratch-fixture-02\"")
        @test_throws SR.SchemaViolation SR.validate_pair(p, SR.validate_analysis_plan(Vector{UInt8}(other_id)))
    end

    @testset "ordered case digest (§7b)" begin
        ids = SR.canonical_case_ids(SR.validate_profile(Vector{UInt8}(SCRATCH_PROFILE)))
        @test ids == ["case-" * lpad(string(i), 2, '0') for i in 0:15]
        @test SR.case_digest(ids) == SR.case_digest(copy(ids))
        @test SR.case_digest(["ab", "c"]) != SR.case_digest(["a", "bc"])
        @test SR.case_digest(ids) != SR.case_digest(reverse(ids))
        @test_throws ArgumentError SR.case_digest(["Case-00"])
        @test_throws ArgumentError SR.case_digest(["case-é"])
        @test_throws ArgumentError SR.case_digest(["case-00\n"])
        @test !SR._kind_ok(:hex40, "a"^40 * "\n")
        @test !SR._kind_ok(:id, "scratch\n")
    end

    @testset "valid baseline, run-start record and completion" begin
        mktempdir() do root
            f = baseline(root)
            token = verify(f)
            @test token isa SR.VerifiedRegistration
            @test token.observed_remote_oid == f.R
            @test token.profile_commit == f.P
            @test token.author_declared_at_semantics == "self_declared_not_used_for_ordering"
            record = SR.build_run_start_record(token; run_id="scratch-run-01")
            @test SR.validate_run_start_record(record)
            path = joinpath(root, "start.toml")
            digest = SR.write_run_start_record(path, record)
            @test digest == sha(read(path))
            @test_throws ArgumentError SR.write_run_start_record(path, record)
            bytes = read(path)
            done = SR.completion_manifest(bytes, token.case_ids, SR.runner_state(f.runner))
            @test done["status"] == "complete"
            @test done["run_start_record_digest"] == digest
            @test SR.validate_completion_manifest(done)
            mpath = joinpath(root, "done.toml")
            @test SR.write_completion_manifest(mpath, bytes, token.case_ids, SR.runner_state(f.runner)) == done
            @test TOML.parsefile(mpath)["status"] == "complete"
            @test_throws ArgumentError SR.write_completion_manifest(mpath, bytes, token.case_ids, SR.runner_state(f.runner))
            forged = copy(done); forged["mismatches"] = ["hSelf holds"]; forged["status"] = "incomplete"
            @test_throws SR.SchemaViolation SR.validate_completion_manifest(forged)
            write_file(f.runner, "Manifest.toml", "# changed\n")
            commit_all(f.runner, "manifest drift")
            drift = SR.completion_manifest(bytes, token.case_ids, SR.runner_state(f.runner))
            @test drift["status"] == "incomplete"
            @test "manifest_sha256" in drift["mismatches"]
        end
    end

    @testset "falsification (§9, local)" begin
        # BLOB: one byte of the profile changes in the runner.
        mktempdir() do root
            f = baseline(root)
            write_file(f.runner, PROFILE_PATH, replace(SCRATCH_PROFILE, "case_count = 16" => "case_count = 16 "))
            commit_all(f.runner, "one byte")
            @test rejected(verify(f), :RUNNER_PROFILE_MISMATCH)
        end
        # COMMENT-ONLY: a comment change gives a different digest and fails.
        mktempdir() do root
            f = baseline(root)
            changed = replace(SCRATCH_PROFILE, "# synthetic fixture" => "# synthetic  fixture")
            @test sha(changed) != sha(SCRATCH_PROFILE)
            @test SR.validate_profile(Vector{UInt8}(changed)) isa AbstractDict
            write_file(f.runner, PROFILE_PATH, changed)
            commit_all(f.runner, "comment")
            @test rejected(verify(f), :RUNNER_PROFILE_MISMATCH)
        end
        # UNKNOWN-KEY: unknown key, unknown section, and a key shared by both files.
        @test_throws SR.SchemaViolation SR.validate_profile(Vector{UInt8}(SCRATCH_PROFILE * "\nextra = 1\n"))
        @test_throws SR.SchemaViolation SR.validate_profile(Vector{UInt8}(SCRATCH_PROFILE * "\n[extra]\nx = 1\n"))
        @test_throws SR.SchemaViolation SR.validate_analysis_plan(Vector{UInt8}("schema_version = 3\n" * SCRATCH_ANALYSIS))
        p = SR.validate_profile(Vector{UInt8}(SCRATCH_PROFILE))
        a = SR.validate_analysis_plan(Vector{UInt8}(SCRATCH_ANALYSIS))
        a2 = copy(a); a2["protocol_version"] = "scratch-protocol"
        @test_throws SR.SchemaViolation SR.validate_pair(p, a2)
        # The exact schemas themselves share no key except the identity allowlist, so no file
        # that passes its schema can carry a key of the other file.
        @test intersect(Set(keys(SR.PROFILE_SCHEMA)), Set(keys(SR.ANALYSIS_SCHEMA))) ==
            Set(SR.SHARED_IDENTITY_FIELDS)
        # UNREGISTERED: no registry row for the requested registration.
        mktempdir() do root
            f = baseline(root)
            r = SR._verify(f.R; registration_id="scratch-reg-99", runner_repo=f.runner,
                remote_url=f.bare, remote_ref="refs/heads/main")
            @test rejected(r, :UNREGISTERED)
        end
        mktempdir() do root
            work = new_work(root)
            write_file(work, PROFILE_PATH, SCRATCH_PROFILE)
            write_file(work, ANALYSIS_PATH, SCRATCH_ANALYSIS)
            commit_all(work, "profile")
            write_file(work, "specs/substrate-registry.toml", "registry_schema_version = 1\nregistration = []\nwithdrawal = []\n")
            R = commit_all(work, "empty registry")
            bare, runner = publish(root, work)
            r = SR._verify(R; registration_id="scratch-reg-01", runner_repo=runner,
                remote_url=bare, remote_ref="refs/heads/main")
            @test rejected(r, :UNREGISTERED)
        end
        # BOTH-SWAPPED: profile and caller expectation replaced together.
        mktempdir() do root
            f = baseline(root)
            swapped = replace(SCRATCH_PROFILE, "protocol_version = \"scratch-protocol\"" => "protocol_version = \"scratch-protocol-b\"")
            write_file(f.runner, PROFILE_PATH, swapped)
            commit_all(f.runner, "swap")
            @test rejected(verify(f; expected_profile_blob_sha256=sha(swapped)), :CALLER_EXPECTATION_MISMATCH)
            @test rejected(verify(f), :RUNNER_PROFILE_MISMATCH)
        end
        # ANALYSIS-DRIFT: only the analysis plan changes; the old registration no longer verifies.
        mktempdir() do root
            f = baseline(root)
            write_file(f.runner, ANALYSIS_PATH, replace(SCRATCH_ANALYSIS, "stop_conditions = [\"scratch\"]" => "stop_conditions = [\"changed\"]"))
            commit_all(f.runner, "analysis drift")
            @test rejected(verify(f), :RUNNER_ANALYSIS_MISMATCH)
        end
        # ANALYSIS-BOTH-SWAPPED
        mktempdir() do root
            f = baseline(root)
            swapped = replace(SCRATCH_ANALYSIS, "id = \"SCRATCH-1\"" => "id = \"SCRATCH-2\"")
            write_file(f.runner, ANALYSIS_PATH, swapped)
            commit_all(f.runner, "swap analysis")
            @test rejected(verify(f; expected_analysis_plan_digest=sha(swapped)), :CALLER_EXPECTATION_MISMATCH)
            @test rejected(verify(f), :RUNNER_ANALYSIS_MISMATCH)
        end
        # ORDER: swapping two case IDs fails the completion check.
        mktempdir() do root
            f = baseline(root)
            token = verify(f)
            bytes = SR._toml_bytes(SR.build_run_start_record(token; run_id="scratch-run-02"))
            ids = copy(token.case_ids)
            ids[1], ids[2] = ids[2], ids[1]
            m = SR.completion_manifest(bytes, ids, SR.runner_state(f.runner))
            @test m["status"] == "incomplete"
            @test "case_ids_ordered" in m["mismatches"]
        end
        # RUNNER-DIRTY: an untracked file, or an uncommitted change to a tracked file,
        # prevents the token.
        mktempdir() do root
            f = baseline(root)
            write_file(f.runner, "scratch-untracked.txt", "x")
            @test rejected(verify(f), :RUNNER_DIRTY)
        end
        mktempdir() do root
            f = baseline(root)
            write_file(f.runner, "Manifest.toml", "# edited, not committed\n")
            @test rejected(verify(f), :RUNNER_DIRTY)
        end
        # NO-MEASUREMENT: records cannot carry relations, trajectories or DC conditions,
        # and the module exposes no measurement or DC entry point.
        mktempdir() do root
            f = baseline(root)
            record = SR.build_run_start_record(verify(f); run_id="scratch-run-03")
            for key in ("hSelf", "hSMC", "hAct", "hBound", "alpha_relation", "trajectory")
                bad = copy(record); bad[key] = true
                @test_throws SR.SchemaViolation SR.validate_run_start_record(bad)
            end
        end
        forbidden = r"check_dc|hself|hsmc|hact|hbound|simulate|trajectory|measure_|erie_state"i
        @test isempty(filter(n -> occursin(forbidden, String(n)), names(SR; all=true)))
    end

    @testset "falsification (§9, remote fixture)" begin
        # REMOTE-WRONG-REF
        mktempdir() do root
            f = baseline(root)
            r = SR._verify(f.R; registration_id="scratch-reg-01", runner_repo=f.runner,
                remote_url=f.bare, remote_ref="refs/heads/absent")
            @test rejected(r, :REMOTE_WRONG_REF) && r.status === :FAILED
        end
        # REMOTE-REG-UNREACHABLE: R exists in the fixture on another branch only.
        mktempdir() do root
            work = new_work(root)
            write_file(work, PROFILE_PATH, SCRATCH_PROFILE)
            write_file(work, ANALYSIS_PATH, SCRATCH_ANALYSIS)
            P = commit_all(work, "profile")
            git(work, "checkout", "-q", "-b", "side")
            bare = joinpath(root, "remote.git")
            write_file(work, "specs/substrate-registry.toml", registry_toml([registry_row(; profile_commit=P, remote=bare)]))
            R = commit_all(work, "registration on side")
            git(work, "checkout", "-q", "main")
            bare, runner = publish(root, work)
            @test occursin(R, git(bare, "rev-parse", "refs/heads/side"))
            r = SR._verify(R; registration_id="scratch-reg-01", runner_repo=runner,
                remote_url=bare, remote_ref="refs/heads/main")
            @test rejected(r, :REMOTE_REG_UNREACHABLE)
        end
        # REMOTE-NOT-DESCENDANT: P and R both reachable through a merge, R not after P.
        mktempdir() do root
            work = new_work(root)
            base = commit_all(work, "base")
            write_file(work, PROFILE_PATH, SCRATCH_PROFILE)
            write_file(work, ANALYSIS_PATH, SCRATCH_ANALYSIS)
            P = commit_all(work, "profile")
            git(work, "checkout", "-q", "-b", "side", base)
            write_file(work, PROFILE_PATH, SCRATCH_PROFILE)
            write_file(work, ANALYSIS_PATH, SCRATCH_ANALYSIS)
            commit_all(work, "same bytes on side")
            bare = joinpath(root, "remote.git")
            write_file(work, "specs/substrate-registry.toml", registry_toml([registry_row(; profile_commit=P, remote=bare)]))
            R = commit_all(work, "registration on side")
            git(work, "checkout", "-q", "main")
            git(work, "merge", "-q", "--no-edit", "side")
            bare, runner = publish(root, work)
            r = SR._verify(R; registration_id="scratch-reg-01", runner_repo=runner,
                remote_url=bare, remote_ref="refs/heads/main")
            @test rejected(r, :REMOTE_NOT_DESCENDANT)
        end
        # REMOTE-PROFILE-BLOB-MISMATCH: only the profile_commit tree differs.
        mktempdir() do root
            work = new_work(root)
            write_file(work, PROFILE_PATH, SCRATCH_PROFILE)
            write_file(work, ANALYSIS_PATH, SCRATCH_ANALYSIS)
            P = commit_all(work, "profile")
            later = replace(SCRATCH_PROFILE, "protocol_version = \"scratch-protocol\"" => "protocol_version = \"scratch-protocol-b\"")
            write_file(work, PROFILE_PATH, later)
            commit_all(work, "profile changed after P")
            bare = joinpath(root, "remote.git")
            write_file(work, "specs/substrate-registry.toml", registry_toml([registry_row(; profile_commit=P, remote=bare, profile=later)]))
            R = commit_all(work, "registration")
            bare, runner = publish(root, work)
            r = SR._verify(R; registration_id="scratch-reg-01", runner_repo=runner,
                remote_url=bare, remote_ref="refs/heads/main")
            @test rejected(r, :REMOTE_PROFILE_BLOB_MISMATCH)
        end
        # REMOTE-REG-BLOB-MISMATCH: only the registration_commit tree differs.
        mktempdir() do root
            work = new_work(root)
            write_file(work, PROFILE_PATH, SCRATCH_PROFILE)
            write_file(work, ANALYSIS_PATH, SCRATCH_ANALYSIS)
            P = commit_all(work, "profile")
            bare = joinpath(root, "remote.git")
            write_file(work, PROFILE_PATH, replace(SCRATCH_PROFILE, "protocol_version = \"scratch-protocol\"" => "protocol_version = \"scratch-protocol-b\""))
            write_file(work, "specs/substrate-registry.toml", registry_toml([registry_row(; profile_commit=P, remote=bare)]))
            R = commit_all(work, "registration with changed profile")
            bare, runner = publish(root, work)
            r = SR._verify(R; registration_id="scratch-reg-01", runner_repo=runner,
                remote_url=bare, remote_ref="refs/heads/main")
            @test rejected(r, :REMOTE_REG_BLOB_MISMATCH)
        end
        # REMOTE-UNREACHABLE: transport failure is UNVERIFIED, never success.
        mktempdir() do root
            f = baseline(root)
            r = SR._verify(f.R; registration_id="scratch-reg-01", runner_repo=f.runner,
                remote_url=joinpath(root, "missing.git"), remote_ref="refs/heads/main")
            @test rejected(r, :REMOTE_UNREACHABLE) && r.status === :UNVERIFIED
        end
    end

    @testset "fixed remote is a literal of the validator" begin
        @test SR.FIXED_REMOTE_URL == "https://github.com/yaaman18/bridge-protocol.git"
        @test SR.FIXED_REMOTE_REF == "refs/heads/main"
        mktempdir() do root
            f = baseline(root)
            # The public API has no way to name another remote.
            @test_throws MethodError SR.verify_substrate_registration(f.R;
                registration_id="scratch-reg-01", runner_repo=f.runner, remote_url=f.bare)
            @test_throws MethodError SR.verify_substrate_registration(f.R;
                registration_id="scratch-reg-01", runner_repo=f.runner, remote_ref="refs/heads/main")
            # A registry row naming another remote fails the registry schema.
            r = SR._verify(f.R; registration_id="scratch-reg-01", runner_repo=f.runner,
                remote_url=f.bare * "/", remote_ref="refs/heads/main")
            @test rejected(r, :REGISTRY_SCHEMA)
            bytes = Vector{UInt8}(registry_toml([registry_row(; profile_commit=f.P, remote=f.bare)]))
            @test_throws SR.SchemaViolation SR.validate_registry(bytes)
        end
    end

    @testset "registration conditions without a §9 ID" begin
        # (iv): bytes changed and changed back between P and R.
        mktempdir() do root
            work = new_work(root)
            write_file(work, PROFILE_PATH, SCRATCH_PROFILE)
            write_file(work, ANALYSIS_PATH, SCRATCH_ANALYSIS)
            P = commit_all(work, "profile")
            write_file(work, PROFILE_PATH, SCRATCH_PROFILE * "# temporary\n")
            commit_all(work, "change")
            write_file(work, PROFILE_PATH, SCRATCH_PROFILE)
            commit_all(work, "revert")
            bare = joinpath(root, "remote.git")
            write_file(work, "specs/substrate-registry.toml", registry_toml([registry_row(; profile_commit=P, remote=bare)]))
            R = commit_all(work, "registration")
            bare, runner = publish(root, work)
            r = SR._verify(R; registration_id="scratch-reg-01", runner_repo=runner,
                remote_url=bare, remote_ref="refs/heads/main")
            @test rejected(r, :PATHS_CHANGED)
        end
        # (iv): a side branch that never touches the files, merged after P, is accepted.
        mktempdir() do root
            work = new_work(root)
            base = commit_all(work, "base")
            write_file(work, PROFILE_PATH, SCRATCH_PROFILE)
            write_file(work, ANALYSIS_PATH, SCRATCH_ANALYSIS)
            P = commit_all(work, "profile")
            git(work, "checkout", "-q", "-b", "side", base)
            write_file(work, "notes.txt", "unrelated\n")
            commit_all(work, "unrelated work")
            git(work, "checkout", "-q", "main")
            git(work, "merge", "-q", "--no-edit", "side")
            bare = joinpath(root, "remote.git")
            write_file(work, "specs/substrate-registry.toml", registry_toml([registry_row(; profile_commit=P, remote=bare)]))
            R = commit_all(work, "registration")
            bare, runner = publish(root, work)
            r = SR._verify(R; registration_id="scratch-reg-01", runner_repo=runner,
                remote_url=bare, remote_ref="refs/heads/main")
            @test r isa SR.VerifiedRegistration
        end
        # §7(4): a symlink is not a regular blob.
        mktempdir() do root
            work = new_work(root)
            write_file(work, "real-profile.toml", SCRATCH_PROFILE)
            mkpath(joinpath(work, "specs"))
            symlink("../real-profile.toml", joinpath(work, PROFILE_PATH))
            write_file(work, ANALYSIS_PATH, SCRATCH_ANALYSIS)
            P = commit_all(work, "profile as symlink")
            bare = joinpath(root, "remote.git")
            write_file(work, "specs/substrate-registry.toml", registry_toml([registry_row(; profile_commit=P, remote=bare)]))
            R = commit_all(work, "registration")
            bare, runner = publish(root, work)
            r = SR._verify(R; registration_id="scratch-reg-01", runner_repo=runner,
                remote_url=bare, remote_ref="refs/heads/main")
            @test rejected(r, :REG_BLOB_MISSING)
        end
        # §3: a registered profile that fails the exact schema yields no token.
        mktempdir() do root
            invalid = SCRATCH_PROFILE * "\nextra = 1\n"
            f = baseline(root; profile=invalid)
            @test rejected(verify(f), :SCHEMA)
        end
        # Registry with an unknown key.
        mktempdir() do root
            work = new_work(root)
            write_file(work, PROFILE_PATH, SCRATCH_PROFILE)
            write_file(work, ANALYSIS_PATH, SCRATCH_ANALYSIS)
            P = commit_all(work, "profile")
            bare = joinpath(root, "remote.git")
            write_file(work, "specs/substrate-registry.toml",
                registry_toml([registry_row(; profile_commit=P, remote=bare) * "hSelf = true\n"]))
            R = commit_all(work, "registration")
            bare, runner = publish(root, work)
            r = SR._verify(R; registration_id="scratch-reg-01", runner_repo=runner,
                remote_url=bare, remote_ref="refs/heads/main")
            @test rejected(r, :REGISTRY_SCHEMA)
        end
    end

    @testset "withdrawal (append-only)" begin
        # Append a registry commit on top of the baseline and publish it to the fixture remote.
        function append_registry!(f, content)
            write_file(f.work, "specs/substrate-registry.toml", content)
            commit_all(f.work, "registry update")
            git(f.work, "push", "-q", f.bare, "main")
        end
        row_a(f; kw...) = registry_row(; profile_commit=f.P, remote=f.bare, kw...)

        mktempdir() do root
            f = baseline(root)
            @test verify(f).preregistration_strength == "full"
            append_registry!(f, registry_toml([row_a(f)]; withdrawals=[withdrawal_row("scratch-reg-01")]))
            @test rejected(verify(f), :WITHDRAWN)
        end
        # A replacement registered together with the withdrawal verifies; the withdrawn one does not.
        for (seen, strength) in ((false, "full"), (true, "post_results_replacement"))
            mktempdir() do root
                f = baseline(root)
                rows = [row_a(f), row_a(f; id="scratch-reg-02", supersedes="scratch-reg-01")]
                append_registry!(f, registry_toml(rows;
                    withdrawals=[withdrawal_row("scratch-reg-01"; superseded_by="scratch-reg-02", seen)]))
                R2 = git(f.work, "rev-parse", "HEAD")
                r2 = SR._verify(R2; registration_id="scratch-reg-02", runner_repo=f.runner,
                    remote_url=f.bare, remote_ref="refs/heads/main")
                @test r2 isa SR.VerifiedRegistration
                @test r2.preregistration_strength == strength
                record = SR.build_run_start_record(r2; run_id="scratch-run-10")
                @test record["preregistration_strength"] == strength
                @test SR.validate_run_start_record(record)
                @test rejected(verify(f), :WITHDRAWN)
            end
        end
        # Rows are append-only: editing a registered row at the tip is rejected.
        mktempdir() do root
            f = baseline(root)
            edited = replace(row_a(f), "2026-09-27T00:00:00Z" => "2026-01-01T00:00:00Z")
            append_registry!(f, registry_toml([edited]))
            @test rejected(verify(f), :REGISTRY_ROW_EDITED)
        end
        # Deleting the row or the registry at the tip is rejected.
        mktempdir() do root
            f = baseline(root)
            append_registry!(f, registry_toml(String[]) * "registration = []\n")
            @test rejected(verify(f), :REGISTRY_ROW_EDITED)
        end
        mktempdir() do root
            f = baseline(root)
            rm(joinpath(f.work, "specs/substrate-registry.toml"))
            commit_all(f.work, "registry removed")
            git(f.work, "push", "-q", f.bare, "main")
            @test rejected(verify(f), :REGISTRY_MISSING)
        end
        # Schema consistency of withdrawals and supersedes.
        mktempdir() do root
            bare = "file:///scratch"
            row = registry_row(; profile_commit="a"^40, remote=bare)
            ok(b) = SR.validate_registry(Vector{UInt8}(b); remote_url=bare, remote_ref="refs/heads/main")
            @test ok(registry_toml([row])) isa AbstractDict
            @test_throws SR.SchemaViolation ok(registry_toml([row]; withdrawals=[withdrawal_row("scratch-reg-99")]))
            @test_throws SR.SchemaViolation ok(registry_toml([row];
                withdrawals=[withdrawal_row("scratch-reg-01"), withdrawal_row("scratch-reg-01")]))
            @test_throws SR.SchemaViolation ok(registry_toml([row];
                withdrawals=[withdrawal_row("scratch-reg-01"; superseded_by="scratch-reg-01")]))
            replacement = registry_row(; id="scratch-reg-02", profile_commit="a"^40, remote=bare,
                supersedes="scratch-reg-01")
            @test_throws SR.SchemaViolation ok(registry_toml([row, replacement]))
            @test ok(registry_toml([row, replacement]; withdrawals=[withdrawal_row("scratch-reg-01")])) isa AbstractDict
        end
    end

    @testset "cli" begin
        mktempdir() do root
            path = joinpath(root, "p.toml")
            write(path, SCRATCH_PROFILE)
            @test SR.main(["validate-profile", path]; io=devnull) == 0
            write(path, SCRATCH_PROFILE * "\nextra = 1\n")
            @test SR.main(["validate-profile", path]; io=devnull) == 1
            @test SR.main(String[]; io=devnull) == 64
        end
    end
end
