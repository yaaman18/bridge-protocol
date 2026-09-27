# A synthetic registration on a local bare remote (RSB-001 §11: scratch fixtures only).

const SCRATCH_OUTPUT = """
[output]
record_all_cases = true
phenomenal_claim = "not_certified"
case_record_format = "rsb-case-record-v1"
set_encoding = "unit_index_lsb_bitmask"
case_record_fields = ["case_id", "q", "preparation_trace", "z", "kappa", "epsilon", "future_final", "future_persistent", "pi", "rho", "alpha", "sigma", "loss_sets", "collective_only_loss"]
"""

scratch_profile(; v1=false) = """
# synthetic fixture, not a candidate
schema_version = $(v1 ? 3 : 4)
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

""" * (v1 ? "[output]\nrecord_all_cases = true\nphenomenal_claim = \"not_certified\"\n" : SCRATCH_OUTPUT)

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
recorded_criteria = ["dc", "dc2"]
dc2_sigma_cover_cases = "recorded_not_counted_as_hinge_evidence"
post_results_replacement = "not_preregistered_evidence"

[incomplete_runs]
missing_case = "run_incomplete"
duplicate_case = "run_invalid"

[decisions]
retraction_conditions = ["scratch"]
stop_conditions = ["scratch"]
forbidden_adjustments = ["scratch"]

[[falsification]]
id = "SCRATCH-1"
condition = "scratch"
expected = "scratch"
"""

function _git(dir, args...)
    cmd = `git -C $dir -c user.name=fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false $(collect(String, args))`
    env = Dict{String,String}(k => v for (k, v) in ENV if !startswith(k, "GIT_"))
    env["GIT_CONFIG_NOSYSTEM"] = "1"
    env["GIT_CONFIG_GLOBAL"] = "/dev/null"
    String(strip(read(setenv(cmd, env), String)))
end

function _put(repo, path, content)
    full = joinpath(repo, path)
    mkpath(dirname(full))
    write(full, content)
end

function _commit(repo, message)
    _git(repo, "add", "-A")
    _git(repo, "commit", "-q", "-m", message)
    _git(repo, "rev-parse", "HEAD")
end

function scratch_registration(root; v1=false)
    work = joinpath(root, "work")
    mkpath(work)
    _git(work, "init", "-q", "-b", "main")
    _put(work, "Manifest.toml", "# fixture manifest\n")
    profile = scratch_profile(; v1)
    _put(work, "specs/scratch-profile.toml", profile)
    _put(work, "specs/scratch-analysis.toml", SCRATCH_ANALYSIS)
    P = _commit(work, "profile")
    bare = joinpath(root, "remote.git")
    sha(s) = bytes2hex(sha256(Vector{UInt8}(s)))
    _put(work, "specs/substrate-registry.toml", """
    registry_schema_version = 1
    withdrawal = []

    [[registration]]
    registration_id = "scratch-reg-01"
    profile_path = "specs/scratch-profile.toml"
    analysis_plan_path = "specs/scratch-analysis.toml"
    profile_blob_sha256 = "$(sha(profile))"
    analysis_plan_digest = "$(sha(SCRATCH_ANALYSIS))"
    profile_commit = "$P"
    remote_url = "$bare"
    remote_ref = "refs/heads/main"
    profile_schema_validation_version = "$(v1 ? "rsb-profile-schema-v1" : "rsb-profile-schema-v2")"
    analysis_schema_validation_version = "rsb-analysis-schema-v1"
    author_declared_at = "2026-09-27T00:00:00Z"
    author_declared_at_semantics = "self_declared_not_used_for_ordering"
    supersedes = ""
    """)
    R = _commit(work, "registration")
    _git(root, "clone", "-q", "--bare", work, bare)
    runner = joinpath(root, "runner")
    _git(root, "clone", "-q", bare, runner)
    (; bare, runner, P, R)
end
