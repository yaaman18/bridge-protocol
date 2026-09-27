# Exact schemas (RSB-001 §3, §4). Unknown sections and keys are rejected, so the raw-byte
# digest never covers content that the schema does not name.

# v1 is kept so that registrations made under it still verify; v2 adds the output schema
# (RSB-002 R2). New registrations use the latest version.
const PROFILE_SCHEMA_V1 = "rsb-profile-schema-v1"
const PROFILE_SCHEMA_V2 = "rsb-profile-schema-v2"
const PROFILE_SCHEMA_VERSIONS = [PROFILE_SCHEMA_V1, PROFILE_SCHEMA_V2]
const PROFILE_SCHEMA_VALIDATION_VERSION = PROFILE_SCHEMA_V2
const ANALYSIS_SCHEMA_VALIDATION_VERSION = "rsb-analysis-schema-v1"
const REGISTRY_SCHEMA_VERSION = 1

# Keys that may appear in both files; their values must agree (RSB-001 §4).
const SHARED_IDENTITY_FIELDS = ("profile_id",)

const ID_PATTERN = r"^[a-z0-9][a-z0-9._-]{0,63}\z"

struct SchemaViolation <: Exception
    errors::Vector{String}
end

Base.showerror(io::IO, e::SchemaViolation) =
    print(io, "SchemaViolation:\n  ", join(e.errors, "\n  "))

struct FieldSpec
    kind::Symbol
    allowed::Union{Nothing,Vector{Any}}
end

field(kind::Symbol; allowed=nothing) =
    FieldSpec(kind, allowed === nothing ? nothing : collect(Any, allowed))

struct TableArraySpec
    row::Dict{String,Any}
    min_rows::Int
end

_is_int(x) = x isa Int64
_is_int_list(x) = x isa AbstractVector && all(_is_int, x)

function _kind_ok(kind::Symbol, x)
    kind === :string && return x isa String
    kind === :int && return _is_int(x)
    kind === :bool && return x isa Bool
    kind === :string_list && return x isa AbstractVector && all(v -> v isa String, x)
    kind === :int_list && return _is_int_list(x)
    kind === :int_triples && return x isa AbstractVector &&
        all(v -> _is_int_list(v) && length(v) == 3, x)
    kind === :hex64 && return x isa String && occursin(r"^[0-9a-f]{64}\z", x)
    kind === :hex40 && return x isa String && occursin(r"^[0-9a-f]{40}\z", x)
    kind === :id && return x isa String && occursin(ID_PATTERN, x)
    kind === :id_or_empty && return x isa String && (isempty(x) || occursin(ID_PATTERN, x))
    kind === :relpath && return x isa String && _is_safe_relpath(x)
    kind === :timestamp && return x isa String &&
        occursin(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\z", x)
    error("unknown field kind $kind")
end

function _is_safe_relpath(p::String)
    isempty(p) && return false
    startswith(p, "/") && return false
    occursin('\\', p) && return false
    parts = split(p, '/')
    all(s -> !isempty(s) && s != "." && s != "..", parts)
end

function _check!(errors::Vector{String}, data, schema::Dict{String,Any}, path::String)
    where = isempty(path) ? "(top level)" : path
    if !(data isa AbstractDict)
        push!(errors, "$where: expected a table")
        return errors
    end
    for key in sort!(collect(keys(data)))
        haskey(schema, key) || push!(errors, "$where: unknown key `$key`")
    end
    for key in sort!(collect(keys(schema)))
        spec = schema[key]
        if !haskey(data, key)
            push!(errors, "$where: missing key `$key`")
            continue
        end
        value = data[key]
        keypath = isempty(path) ? key : "$path.$key"
        if spec isa FieldSpec
            if !_kind_ok(spec.kind, value)
                push!(errors, "$keypath: expected $(spec.kind)")
            elseif spec.allowed !== nothing && !(value in spec.allowed)
                push!(errors, "$keypath: value $(repr(value)) is not permitted")
            end
        elseif spec isa TableArraySpec
            if !(value isa AbstractVector) || !all(v -> v isa AbstractDict, value)
                push!(errors, "$keypath: expected an array of tables")
            else
                length(value) >= spec.min_rows ||
                    push!(errors, "$keypath: expected at least $(spec.min_rows) rows")
                for (i, row) in enumerate(value)
                    _check!(errors, row, spec.row, "$keypath[$i]")
                end
            end
        else
            _check!(errors, value, spec, keypath)
        end
    end
    errors
end

const PROFILE_SCHEMA_V1_KEYS = Dict{String,Any}(
    "schema_version" => field(:int; allowed=[3]),
    "profile_id" => field(:id),
    "protocol_version" => field(:string),
    "digest_format" => field(:string; allowed=["sha256_file_bytes"]),
    "substrate" => Dict{String,Any}(
        "unit_count" => field(:int),
        "units" => field(:string_list),
        "input_units" => field(:string_list),
        "output_units" => field(:string_list),
        "internal_units" => field(:string_list),
        "require_disjoint_io" => field(:bool; allowed=[true]),
        "state_values" => field(:int_list),
        "arithmetic" => field(:string),
        "weight_sum_bound" => field(:int),
        "thresholds" => field(:int_list),
        "weights" => field(:int_triples),
        "environment_map" => field(:int_triples),
        "update_rule" => field(:string),
        "ordinary_edges_to_input" => field(:string; allowed=["forbidden"]),
        "exogenous_drive" => field(:string),
        "self_edges" => field(:string; allowed=["forbidden"]),
        "duplicate_edges" => field(:string; allowed=["reject"]),
        "zero_weight_edges" => field(:string; allowed=["reject"]),
    ),
    "observation" => Dict{String,Any}(
        "kappa_rule" => field(:string),
        "kappa_transitions" => field(:int),
        "state_window_points" => field(:int),
        "preparation_steps" => field(:int),
        "intervention_horizon_steps" => field(:int),
        "effect_window_points" => field(:int),
        "epsilon_rule" => field(:string),
        "boundary_rule" => field(:string),
        "boundary_edge_sources" => field(:string_list),
        "initial_history" => field(:string),
        "persistence_only" => field(:bool),
        "carrier" => field(:string),
    ),
    "measurement" => Dict{String,Any}(
        k => field(:string) for k in (
            "intervention_rule", "intervention_scope", "intervention_subsets",
            "alpha_rule", "sigma_rule", "pi_rule", "rho_rule", "direct_self_effect",
            "coalition_rule", "coalition_projection_to_unary_relations",
            "relation_scope", "trial_sharing", "relation_aggregation")
    ),
    "enumeration" => Dict{String,Any}(
        "policy" => field(:string; allowed=["exhaustive"]),
        "bit_order" => field(:string),
        "case_order" => field(:string; allowed=["ascending_integer"]),
        "case_count" => field(:int),
        "early_success_stop" => field(:bool; allowed=[false]),
    ),
    # What to output (RSB-001 §3). How to read it lives in the analysis plan.
    "output" => Dict{String,Any}(
        "record_all_cases" => field(:bool; allowed=[true]),
        "phenomenal_claim" => field(:string; allowed=["not_certified"]),
    ),
)

# v2: same substrate, observation, measurement and enumeration keys; schema_version 4 and an
# output section that fixes the case-record format under the profile digest (RSB-001 §3).
const PROFILE_SCHEMA_V2_KEYS = let d = deepcopy(PROFILE_SCHEMA_V1_KEYS)
    d["schema_version"] = field(:int; allowed=[4])
    d["output"] = Dict{String,Any}(
        "record_all_cases" => field(:bool; allowed=[true]),
        "phenomenal_claim" => field(:string; allowed=["not_certified"]),
        "case_record_format" => field(:string; allowed=["rsb-case-record-v1"]),
        "set_encoding" => field(:string; allowed=["unit_index_lsb_bitmask"]),
        "case_record_fields" => field(:string_list),
    )
    d
end

const PROFILE_SCHEMAS = Dict{String,Dict{String,Any}}(
    PROFILE_SCHEMA_V1 => PROFILE_SCHEMA_V1_KEYS,
    PROFILE_SCHEMA_V2 => PROFILE_SCHEMA_V2_KEYS,
)

const ANALYSIS_SCHEMA = Dict{String,Any}(
    "analysis_schema_version" => field(:int; allowed=[1]),
    "profile_id" => field(:id),
    "analysis_plan_id" => field(:id),
    "interpretation" => Dict{String,Any}(
        "zero_pass_count" => field(:string),
        "nonempty_flags" => field(:string),
        "non_dc_interpretation" => field(:string),
        "claim_scope" => field(:string),
        "primary_criterion" => field(:string; allowed=["dc"]),
        # A registration that replaces one withdrawn after results were seen is not read as
        # preregistered evidence (see the registry `[[withdrawal]]` table).
        "post_results_replacement" => field(:string; allowed=["not_preregistered_evidence"]),
        "recorded_criteria" => field(:string_list),
        "dc2_sigma_cover_cases" => field(:string),
    ),
    "incomplete_runs" => Dict{String,Any}(
        "missing_case" => field(:string),
        "duplicate_case" => field(:string),
    ),
    "decisions" => Dict{String,Any}(
        "retraction_conditions" => field(:string_list),
        "stop_conditions" => field(:string_list),
        "forbidden_adjustments" => field(:string_list),
    ),
    "falsification" => TableArraySpec(Dict{String,Any}(
        "id" => field(:string),
        "condition" => field(:string),
        "expected" => field(:string),
    ), 1),
)

const REGISTRY_SCHEMA = Dict{String,Any}(
    "registry_schema_version" => field(:int; allowed=[REGISTRY_SCHEMA_VERSION]),
    "registration" => TableArraySpec(Dict{String,Any}(
        "registration_id" => field(:id),
        "profile_path" => field(:relpath),
        "analysis_plan_path" => field(:relpath),
        "profile_blob_sha256" => field(:hex64),
        "analysis_plan_digest" => field(:hex64),
        "profile_commit" => field(:hex40),
        "remote_url" => field(:string),
        "remote_ref" => field(:string),
        "profile_schema_validation_version" =>
            field(:string; allowed=PROFILE_SCHEMA_VERSIONS),
        "analysis_schema_validation_version" =>
            field(:string; allowed=[ANALYSIS_SCHEMA_VALIDATION_VERSION]),
        "author_declared_at" => field(:timestamp),
        "author_declared_at_semantics" =>
            field(:string; allowed=["self_declared_not_used_for_ordering"]),
        # Empty, or the registration_id this one replaces (which must be withdrawn).
        "supersedes" => field(:id_or_empty),
    ), 0),
    # Append-only withdrawals. Nothing is deleted; a withdrawn registration stops verifying.
    "withdrawal" => TableArraySpec(Dict{String,Any}(
        "registration_id" => field(:id),
        "reason" => field(:string),
        "superseded_by" => field(:id_or_empty),
        "results_seen_before_withdrawal" => field(:bool),
        "declared_at" => field(:timestamp),
        "declared_at_semantics" =>
            field(:string; allowed=["self_declared_not_used_for_ordering"]),
    ), 0),
)

function _parse_toml(bytes::AbstractVector{UInt8}, what::String)
    text = String(copy(bytes))
    isvalid(text) || throw(SchemaViolation(["$what: not valid UTF-8"]))
    parsed = TOML.tryparse(text)
    parsed isa TOML.ParserError && throw(SchemaViolation(["$what: TOML parse error"]))
    parsed
end

function _profile_semantics!(errors::Vector{String}, p::AbstractDict)
    s = p["substrate"]
    units = s["units"]
    n = s["unit_count"]
    n >= 1 || push!(errors, "substrate.unit_count must be positive")
    length(units) == n || push!(errors, "substrate.units must have unit_count entries")
    allunique(units) || push!(errors, "substrate.units must be unique")
    io = (s["input_units"], s["output_units"], s["internal_units"])
    parts = vcat(io...)
    (allunique(parts) && Set(parts) == Set(units)) ||
        push!(errors, "input/output/internal units must partition units")
    s["state_values"] == [0, 1] || push!(errors, "substrate.state_values must be [0, 1]")
    length(s["thresholds"]) == n || push!(errors, "substrate.thresholds must have unit_count entries")
    index = Dict(u => i - 1 for (i, u) in enumerate(units))
    inputs = Set(index[u] for u in s["input_units"] if haskey(index, u))
    outputs = Set(index[u] for u in s["output_units"] if haskey(index, u))
    seen = Set{Tuple{Int,Int}}()
    total = 0
    for (name, edges) in (("weights", s["weights"]), ("environment_map", s["environment_map"]))
        for (src, dst, w) in edges
            (0 <= src < n && 0 <= dst < n) || push!(errors, "substrate.$name: unit index out of range")
            src != dst || push!(errors, "substrate.$name: self edge ($src,$dst)")
            w != 0 || push!(errors, "substrate.$name: zero weight ($src,$dst)")
            (src, dst) in seen && push!(errors, "substrate.$name: duplicate edge ($src,$dst)")
            push!(seen, (src, dst))
            total += abs(w)
            if name == "weights"
                dst in inputs && push!(errors, "substrate.weights: ordinary edge into input unit $dst")
            else
                src in outputs || push!(errors, "substrate.environment_map: source $src is not an output unit")
                dst in inputs || push!(errors, "substrate.environment_map: target $dst is not an input unit")
            end
        end
    end
    total <= s["weight_sum_bound"] || push!(errors, "substrate: total |weight| exceeds weight_sum_bound")
    o = p["observation"]
    for key in ("kappa_transitions", "state_window_points", "preparation_steps",
            "intervention_horizon_steps", "effect_window_points")
        o[key] >= 1 || push!(errors, "observation.$key must be positive")
    end
    e = p["enumeration"]
    (1 <= n < 63 && e["case_count"] == 2^n) ||
        push!(errors, "enumeration.case_count must equal 2^unit_count for exhaustive enumeration")
    errors
end

"""Parse and validate a profile from raw bytes under the given schema version;
throws `SchemaViolation`."""
function validate_profile(bytes::AbstractVector{UInt8}; version::AbstractString=PROFILE_SCHEMA_VALIDATION_VERSION)
    haskey(PROFILE_SCHEMAS, version) || throw(SchemaViolation(["unknown profile schema version $(repr(version))"]))
    p = _parse_toml(bytes, "profile")
    errors = _check!(String[], p, PROFILE_SCHEMAS[version], "")
    isempty(errors) && _profile_semantics!(errors, p)
    isempty(errors) && version == PROFILE_SCHEMA_V2 && _protocol_semantics!(errors, p)
    isempty(errors) || throw(SchemaViolation(errors))
    p
end

# Time-window constraints of design-r2 §2, enforced from schema v2 on.
function _protocol_semantics!(errors::Vector{String}, p::AbstractDict)
    o = p["observation"]
    P, k, L = o["preparation_steps"], o["kappa_transitions"], o["state_window_points"]
    H, R = o["intervention_horizon_steps"], o["effect_window_points"]
    L == k + 1 || push!(errors, "observation: state_window_points must equal kappa_transitions + 1")
    L <= P + 1 || push!(errors, "observation: state_window_points must not exceed preparation_steps + 1")
    R <= H || push!(errors, "observation: effect_window_points must not exceed intervention_horizon_steps")
    errors
end

"""The profile schema version whose `schema_version` value matches the file, for tools that
are given a file without a registry row."""
function profile_schema_version_of(bytes::AbstractVector{UInt8})
    v = get(_parse_toml(bytes, "profile"), "schema_version", nothing)
    v == 3 && return PROFILE_SCHEMA_V1
    v == 4 && return PROFILE_SCHEMA_V2
    throw(SchemaViolation(["unknown profile schema_version $(repr(v))"]))
end

"""Parse and validate an analysis plan from raw bytes; throws `SchemaViolation`."""
function validate_analysis_plan(bytes::AbstractVector{UInt8})
    a = _parse_toml(bytes, "analysis plan")
    errors = _check!(String[], a, ANALYSIS_SCHEMA, "")
    if isempty(errors)
        ids = [row["id"] for row in a["falsification"]]
        allunique(ids) || push!(errors, "falsification ids must be unique")
    end
    isempty(errors) || throw(SchemaViolation(errors))
    a
end

"""Check the two files together: key sets are disjoint except the identity allowlist,
whose values must agree."""
function validate_pair(profile::AbstractDict, analysis::AbstractDict)
    errors = String[]
    shared = intersect(Set(keys(profile)), Set(keys(analysis)))
    for key in sort!(collect(shared))
        if key in SHARED_IDENTITY_FIELDS
            profile[key] == analysis[key] || push!(errors, "identity field `$key` differs between files")
        else
            push!(errors, "key `$key` appears in both files")
        end
    end
    for key in SHARED_IDENTITY_FIELDS
        (haskey(profile, key) && haskey(analysis, key)) ||
            push!(errors, "identity field `$key` must appear in both files")
    end
    isempty(errors) || throw(SchemaViolation(errors))
    true
end

"""Parse and validate the registry from raw bytes; throws `SchemaViolation`.
Every row must name the fixed remote and ref (RSB-001 §6); the keywords exist only so the
test suite can substitute a local bare fixture."""
function validate_registry(bytes::AbstractVector{UInt8};
        remote_url::String=FIXED_REMOTE_URL, remote_ref::String=FIXED_REMOTE_REF)
    r = _parse_toml(bytes, "registry")
    errors = _check!(String[], r, REGISTRY_SCHEMA, "")
    if isempty(errors)
        ids = [row["registration_id"] for row in r["registration"]]
        allunique(ids) || push!(errors, "registration_id values must be unique")
        for row in r["registration"]
            (row["remote_url"] == remote_url && row["remote_ref"] == remote_ref) ||
                push!(errors, "registration $(row["registration_id"]): remote must be $remote_url $remote_ref")
            row["profile_path"] != row["analysis_plan_path"] ||
                push!(errors, "registration $(row["registration_id"]): profile and analysis plan share a path")
        end
        known = Set(ids)
        withdrawn = [w["registration_id"] for w in r["withdrawal"]]
        allunique(withdrawn) || push!(errors, "a registration is withdrawn more than once")
        for w in r["withdrawal"]
            id, next = w["registration_id"], w["superseded_by"]
            id in known || push!(errors, "withdrawal of unknown registration $id")
            isempty(next) || (next in known && next != id) ||
                push!(errors, "withdrawal of $id: superseded_by must name another registration")
        end
        for row in r["registration"]
            prev = row["supersedes"]
            isempty(prev) && continue
            id = row["registration_id"]
            (prev in known && prev != id) ||
                push!(errors, "registration $id: supersedes must name another registration")
            prev in withdrawn ||
                push!(errors, "registration $id: supersedes $prev, which is not withdrawn")
        end
    end
    isempty(errors) || throw(SchemaViolation(errors))
    r
end
