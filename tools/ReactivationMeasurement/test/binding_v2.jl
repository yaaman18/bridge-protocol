# RSB-BIND-001: criterion binding under analysis schema v2, on scratch registrations only.
# A test-only criterion package (ScratchCriteria) lives inside the runner checkout and is loaded
# from there. It is not DC or DC2.

const SCRATCH_PKG = "ScratchCriteria"
const SCRATCH_PKG_SRC = """
__precompile__(false)
# Test fixture (RSB-BIND-001). Uses the engine already loaded in the test session.
module ScratchCriteria
const RM = Main.ReactivationMeasurement
struct Criterion <: RM.AbstractCriterion
    id::String
    extra_key::Bool
    fail_from::Int      # stops the run from this case number on (RSB-RETRY-001 tests)
end
Criterion(id) = Criterion(id, false, typemax(Int))
Criterion(id, extra_key::Bool) = Criterion(id, extra_key, typemax(Int))
RM.criterion_id(c::Criterion) = c.id
RM.criterion_version(::Criterion) = "scratch-1"
RM.required_structure(::Criterion) = [:n]
function RM.evaluate(c::Criterion, record, structure)
    parse(Int, split(record["case_id"], "-")[end]) >= c.fail_from && error("scratch stop at \$(record["case_id"])")
    d = Dict{String,Any}("n" => structure[:n])
    c.extra_key && (d["extra"] = true)
    Dict("values" => Dict("kappa_nonempty" => record["kappa"] != 0), "diagnostics" => d)
end
end
"""
const SCRATCH_PKG_PROJECT = """
name = "ScratchCriteria"
uuid = "5a2c1b0e-7d3f-4e8a-9b6c-1f0e2d3c4b5a"
version = "0.1.0"
"""

function scratch_analysis_v2(bindings)
    rows = join(["""

    [[criterion_binding]]
    criterion_id = "$(b.id)"
    criterion_version = "$(b.version)"
    package_name = "$SCRATCH_PKG"
    package_path = "$(b.path)"
    package_tree_oid = "$(b.oid)"
    value_keys = ["kappa_nonempty"]
    diagnostic_keys = ["n"]
    dependency_paths = ["tools/OtherCopy", "tools/Missing"]
    """ for b in bindings])
    """
    analysis_schema_version = 2
    profile_id = "scratch-fixture-01"
    analysis_plan_id = "scratch-analysis-02"
    supersedes_analysis_plan = "scratch-analysis-01"

    [interpretation]
    zero_pass_count = "valid_result"
    nonempty_flags = "derived_diagnostics"
    non_dc_interpretation = "supplied_unary_relations_not_certified"
    claim_scope = "finite_horizon_signal_contribution"
    primary_criterion = "dc"
    recorded_criteria = ["dc", "dc2"]
    criterion_result_format = "rsb-criterion-result-v1"
    dc2_sigma_cover_cases = "recorded_not_counted_as_hinge_evidence"
    post_results_replacement = "not_preregistered_evidence"

    [incomplete_runs]
    missing_case = "run_incomplete"
    duplicate_case = "run_invalid"
    max_attempts = 2
    retry_condition = "scratch"
    partial_outputs = "scratch"
    overlap_rule = "scratch"
    after_last_attempt = "scratch"

    [redundancy]
    classification = ["pass", "fail"]
    self_component = "hSelf_T"
    primary_tally = "scratch"
    sensitivity_reading = "scratch"
    robustness_rule = "scratch"
    descriptive_counts = ["scratch"]

    [dc2_unit_informativeness]
    check = "scratch"
    template_labels = "specs/scratch-labels.toml"
    ground_truth_spec = "specs/scratch-truth.md"
    known_differences = "specs/scratch-known.toml"
    report_on = ["scratch"]
    recorded_every_run = ["scratch"]
    on_report = "scratch"

    [decisions]
    retraction_conditions = ["scratch"]
    stop_conditions = ["scratch"]
    forbidden_adjustments = ["scratch"]

    [[falsification]]
    id = "SCRATCH-1"
    condition = "scratch"
    expected = "scratch"
    expected_components = { dc = false }
    """ * rows
end

"""
Scratch registrations under schema v2. `plans` maps a registration id to a function from the
package tree OIDs (Dict path => oid) to the bindings of that plan. `drift_between` changes the
package between profile_commit and registration_commit.
"""
function scratch_registration_v2(root, plans; drift_between=false)
    work = joinpath(root, "work")
    mkpath(work)
    _git(work, "init", "-q", "-b", "main")
    _put(work, "Manifest.toml", "# fixture manifest\n")
    for dir in ("tools/ScratchCriteria", "tools/OtherCopy")
        _put(work, "$dir/Project.toml", SCRATCH_PKG_PROJECT)
        _put(work, "$dir/src/ScratchCriteria.jl", SCRATCH_PKG_SRC)
    end
    A = _commit(work, "criterion package")
    oids = Dict(d => SR.tree_oid_at(work, A, d) for d in ("tools/ScratchCriteria", "tools/OtherCopy"))
    profile = scratch_profile()
    _put(work, "specs/scratch-profile.toml", profile)
    texts = Dict(id => scratch_analysis_v2(f(oids)) for (id, f) in plans)
    for (id, text) in texts
        _put(work, "specs/$id.toml", text)
    end
    P = _commit(work, "profile and plans")
    if drift_between
        _put(work, "tools/ScratchCriteria/src/ScratchCriteria.jl", SCRATCH_PKG_SRC * "# drift\n")
        _commit(work, "package drift")
    end
    bare = joinpath(root, "remote.git")
    sha(s) = bytes2hex(sha256(Vector{UInt8}(s)))
    rows = join(["""

    [[registration]]
    registration_id = "$id"
    profile_path = "specs/scratch-profile.toml"
    analysis_plan_path = "specs/$id.toml"
    profile_blob_sha256 = "$(sha(profile))"
    analysis_plan_digest = "$(sha(text))"
    profile_commit = "$P"
    remote_url = "$bare"
    remote_ref = "refs/heads/main"
    profile_schema_validation_version = "rsb-profile-schema-v2"
    analysis_schema_validation_version = "rsb-analysis-schema-v2"
    author_declared_at = "2026-10-08T00:00:00Z"
    author_declared_at_semantics = "self_declared_not_used_for_ordering"
    supersedes = ""
    """ for (id, text) in sort!(collect(texts))])
    _put(work, "specs/substrate-registry.toml", "registry_schema_version = 1\nwithdrawal = []\n" * rows)
    R = _commit(work, "registration")
    _git(root, "clone", "-q", "--bare", work, bare)
    runner = joinpath(root, "runner")
    _git(root, "clone", "-q", bare, runner)
    (; work, bare, runner, P, R, oids)
end

ok_bindings(oids; path="tools/ScratchCriteria", version="scratch-1") =
    [(id=id, version=version, path=path, oid=oids[path]) for id in ("dc", "dc2")]


function binding_checks(f, root, verify, token)
    SC = Main.ScratchCriteria
    @test realpath(pkgdir(SC)) == realpath(joinpath(f.runner, "tools", "ScratchCriteria"))

    # Each check gets its own runs root, so attempts of one check do not count for another.
    run_with(token, criteria, name; attempt=1) = RM.start_run(token; runner_repo=f.runner,
        run_id="scratch-$name-attempt-$attempt", out_dir=joinpath(root, "runs-$name", "attempt-$attempt"),
        criteria=criteria)
    healthy = [SC.Criterion("dc"), SC.Criterion("dc2")]

    # The registered package, loaded from the registered path: the run completes.
    manifest = run_with(token, [SC.Criterion("dc"), SC.Criterion("dc2")], "ok")
    @test manifest["status"] == "complete"
    # RSB-PLAN-002 §3.5: dependency trees are recorded (an absent path is recorded as absent).
    deps = TOML.parsefile(joinpath(root, "runs-ok", "attempt-1", "run-start.toml"))["dependency_tree_oids"]
    @test "dc|tools/OtherCopy|$(f.oids["tools/OtherCopy"])" in deps
    @test "dc2|tools/Missing|absent" in deps && length(deps) == 4

    # STAND-IN: same names and keys, defined in a test module.
    @test_throws ArgumentError run_with(token, StandIn.PAIR, "standin")
    @test !ispath(joinpath(root, "runs-standin"))

    # FOREIGN-LOAD: the binding names tools/OtherCopy (same package name and tree), but the
    # package was loaded from tools/ScratchCriteria.
    @test_throws ArgumentError run_with(verify("reg-foreign"), [SC.Criterion("dc"), SC.Criterion("dc2")], "foreign")
    @test !ispath(joinpath(root, "runs-foreign"))

    # Version differs from the registered one.
    @test_throws ArgumentError run_with(verify("reg-version"), [SC.Criterion("dc"), SC.Criterion("dc2")], "version")

    # RESULT-KEYS: one extra diagnostic key fails the run on the first case.
    @test_throws ArgumentError run_with(token, [SC.Criterion("dc", true), SC.Criterion("dc2")], "keys")
    @test !ispath(joinpath(root, "runs-keys", "attempt-1", "completion.toml"))

    retry_checks(token, run_with, healthy, SC, root)

    # TREE-DRIFT at run time: the package changes after registration, and the runner moves to
    # that commit. Verification still passes (it binds profile_commit..registration_commit),
    # but start_run refuses the drifted tree.
    _put(f.work, "tools/ScratchCriteria/src/ScratchCriteria.jl", SCRATCH_PKG_SRC * "# drift\n")
    _commit(f.work, "drift after registration")
    _git(f.work, "push", "-q", f.bare, "main")
    _git(f.runner, "pull", "-q", "--ff-only")
    drifted = verify("reg-ok")
    @test drifted isa SR.VerifiedRegistration
    @test_throws ArgumentError run_with(drifted, [SC.Criterion("dc"), SC.Criterion("dc2")], "drift")
    @test !ispath(joinpath(root, "runs-drift"))
end

# RSB-RETRY-001: attempts, seal and overlap (RSB-PLAN-002 §6, §10 RETRY-MISMATCH and THIRD-ATTEMPT).
function retry_checks(token, run_with, healthy, SC, root)
    stopping = [SC.Criterion("dc", false, 5), SC.Criterion("dc2")]      # stops at case 5
    read_toml(path...) = TOML.parsefile(joinpath(root, path...))

    # A first attempt that stops, then a retry that completes and agrees on the overlap.
    @test_throws ErrorException run_with(token, stopping, "retry")
    @test !isfile(joinpath(root, "runs-retry", "attempt-1", "completion.toml"))
    @test length(readdir(joinpath(root, "runs-retry", "attempt-1", "cases"))) == 6     # cases 0..5
    m = run_with(token, healthy, "retry"; attempt=2)
    @test m["status"] == "complete" && m["record_schema_version"] == 3
    start2 = read_toml("runs-retry", "attempt-2", "run-start.toml")
    @test start2["attempt"] == 2 && start2["previous_attempt_run_id"] == "scratch-retry-attempt-1"
    seal = joinpath(root, "runs-retry", "attempt-2", "previous-attempt-seal.toml")
    @test start2["previous_attempt_seal_sha256"] == bytes2hex(open(sha256, seal))
    start1 = read_toml("runs-retry", "attempt-1", "run-start.toml")
    @test start1["attempt"] == 1 && start1["previous_attempt_run_id"] == ""

    # THIRD-ATTEMPT: refused before any output.
    @test_throws ArgumentError run_with(token, healthy, "retry"; attempt=3)
    @test !ispath(joinpath(root, "runs-retry", "attempt-3"))

    # A retry after a completed first attempt is refused.
    @test run_with(token, healthy, "done")["status"] == "complete"
    @test_throws ArgumentError run_with(token, healthy, "done"; attempt=2)

    # The run_id must carry the attempt the engine decides.
    @test_throws ArgumentError RM.start_run(token; runner_repo=f_runner(token, root), run_id="scratch-wrong-attempt-2",
        out_dir=joinpath(root, "runs-wrong", "attempt-1"), criteria=healthy)

    # RETRY-MISMATCH: one byte of an overlapping case record of the first attempt changes before the
    # retry, so the retry disagrees with it: the run is retracted.
    @test_throws ErrorException run_with(token, stopping, "mismatch")
    case0 = joinpath(root, "runs-mismatch", "attempt-1", "cases", "case-00.toml")
    write(case0, read(case0, String) * " ")
    m = run_with(token, healthy, "mismatch"; attempt=2)
    @test m["status"] == "retracted" && "retry_overlap_mismatch" in m["mismatches"]

    # The seal detects a first attempt that changes after sealing.
    prev = joinpath(root, "runs-retry", "attempt-1")
    @test RM.retry_mismatches(prev, seal, joinpath(root, "runs-retry", "attempt-2")) == String[]
    write(joinpath(prev, "cases", "case-01.toml"), "changed after sealing\n")
    @test "previous_attempt_changed" in RM.retry_mismatches(prev, seal, joinpath(root, "runs-retry", "attempt-2"))
end
f_runner(token, root) = joinpath(root, "runner")

@testset "RSB-BIND-001: criterion binding under analysis schema v2" begin
    mktempdir() do root
        f = scratch_registration_v2(root, Dict(
            "reg-ok" => oids -> ok_bindings(oids),
            "reg-foreign" => oids -> ok_bindings(oids; path="tools/OtherCopy"),
            "reg-version" => oids -> ok_bindings(oids; version="scratch-0")))
        verify(id) = SR._verify(f.R; registration_id=id, runner_repo=f.runner,
            remote_url=f.bare, remote_ref="refs/heads/main")
        token = verify("reg-ok")
        @test token isa SR.VerifiedRegistration
        @test token.analysis_schema_validation_version == "rsb-analysis-schema-v2"
        # Load the criterion package from inside the runner checkout.
        push!(LOAD_PATH, joinpath(f.runner, "tools", "ScratchCriteria"))
        @eval Main using ScratchCriteria
        # The package was loaded inside this function; its methods are newer than the caller's
        # world, so everything that uses them runs through invokelatest.
        Base.invokelatest(() -> binding_checks(f, root, verify, token))
    end

    # TREE-DRIFT at registration: the package changes between profile_commit and registration_commit.
    mktempdir() do root
        f = scratch_registration_v2(root, Dict("reg-ok" => oids -> ok_bindings(oids)); drift_between=true)
        r = SR._verify(f.R; registration_id="reg-ok", runner_repo=f.runner,
            remote_url=f.bare, remote_ref="refs/heads/main")
        @test r isa SR.RegistrationRejected && r.code == :BINDING_TREE_CHANGED
    end

    # A registered OID that is not the tree at profile_commit.
    mktempdir() do root
        f = scratch_registration_v2(root, Dict("reg-ok" => oids -> [(id=id, version="scratch-1",
            path="tools/ScratchCriteria", oid="a"^40) for id in ("dc", "dc2")]))
        r = SR._verify(f.R; registration_id="reg-ok", runner_repo=f.runner,
            remote_url=f.bare, remote_ref="refs/heads/main")
        @test r isa SR.RegistrationRejected && r.code == :BINDING_TREE_MISMATCH
    end

    # Schema v2 refusals: bindings must name exactly the recorded criteria; expected_components
    # must be a table of booleans or strings.
    good = scratch_analysis_v2([(id="dc", version="v", path="tools/X", oid="b"^40),
                                (id="dc2", version="v", path="tools/X", oid="b"^40)])
    @test SR.validate_analysis_plan(Vector{UInt8}(good); version="rsb-analysis-schema-v2") isa AbstractDict
    @test_throws SR.SchemaViolation SR.validate_analysis_plan(Vector{UInt8}(good))          # not v1
    only_dc = scratch_analysis_v2([(id="dc", version="v", path="tools/X", oid="b"^40)])
    @test_throws SR.SchemaViolation SR.validate_analysis_plan(Vector{UInt8}(only_dc); version="rsb-analysis-schema-v2")
    bad_components = replace(good, "expected_components = { dc = false }" => "expected_components = { dc = 1 }")
    @test_throws SR.SchemaViolation SR.validate_analysis_plan(Vector{UInt8}(bad_components); version="rsb-analysis-schema-v2")
    unknown = good * "\n[extra]\nx = 1\n"
    @test_throws SR.SchemaViolation SR.validate_analysis_plan(Vector{UInt8}(unknown); version="rsb-analysis-schema-v2")
end
