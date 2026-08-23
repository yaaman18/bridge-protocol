import JSON3
import SHA
import TOML

const MODEL_EVALUATION_SCHEMA_VERSION = 2
const MODEL_EVALUATION_FINGERPRINT_ALGORITHM =
    "sha256:eriec-canonical-model-bytes-v1"
const MODEL_EVALUATION_RAW_FINGERPRINT_ALGORITHM =
    "sha256:eriec-raw-input-bytes-v1"
const _MODEL_EVALUATION_OUTCOMES = Set((:pass, :reject, :error))
const _MODEL_EVALUATION_CLAIM_RELATIONS =
    Set((:observation_only, :counterexample_candidate))
const _MODEL_EVALUATION_ID = r"^[A-Za-z0-9][A-Za-z0-9._-]*$"
const _MODEL_EVALUATION_SHA256 = r"^[0-9a-f]{64}$"
const _MODEL_EVALUATION_CATALOG_CACHE = Dict{Tuple{String,String},Any}()
const _MODEL_EVALUATION_VERIFIED_CONTRACT_CACHE = Set{Tuple{String,String,String}}()
const _MODEL_EVALUATION_CATALOG_LOCK = ReentrantLock()
const _MODEL_EVALUATION_CHECKER_LOCK = ReentrantLock()
const _MODEL_EVALUATION_ID_LOCK = ReentrantLock()
const _MODEL_EVALUATION_ID_COUNTER = Ref{UInt64}(0)
const _MODEL_EVALUATION_LOADED_SOURCE_SHA256 = Dict(
    relpath(path, dirname(@__DIR__)) => bytes2hex(SHA.sha256(read(path)))
    for path in readdir(@__DIR__; join=true)
    if isfile(path) && endswith(path, ".jl")
)
const _MODEL_EVALUATION_PAYLOAD_KEYS = Set([
    "kind", "schema_version", "evaluation_id", "model_fingerprint",
    "fingerprint_algorithm", "source_model_artifact", "source_model_sha256",
    "model_artifact", "model_artifact_sha256", "vp_id", "contract_id",
    "lean_decl", "checker_id", "checker_relation", "checker_source",
    "checker_source_sha256", "checker_version", "adapter_id",
    "adapter_source_origin", "adapter_source", "adapter_source_sha256",
    "adapter_version", "registry_snapshot",
    "registry_snapshot_sha256", "outcome", "failed_predicates",
    "claim_relation", "claim_status", "error_message", "seed",
    "numeric_assumptions", "git_commit", "git_dirty", "julia_version",
    "manifest_sha256", "log_path", "log_sha256", "generated_unix",
    "phenomenal_claim", "execution_layer", "execution_certified",
    "execution_boundary", "execution_note",
])
const _MODEL_EVALUATION_REGISTRY_KEYS = Set([
    "kind", "vp_id", "contract_id", "lean_decl", "checker_id",
    "checker_relation", "checker_source", "scope", "assumptions", "guarantee",
    "catalog_artifact_id", "catalog_version", "ledger_sha256",
    "semantic_manifest_sha256", "certified_artifact_source_sha256",
])

function _model_evaluation_valid_id(value::AbstractString)
    id = String(value)
    occursin(_MODEL_EVALUATION_ID, id) ||
        throw(ArgumentError("evaluation_id must match $(_MODEL_EVALUATION_ID.pattern)"))
    id
end

"""A self-contained empirical checker execution, explicitly not a claim."""
struct ModelEvaluationRecord
    schema_version::Int
    evaluation_id::String
    model_fingerprint::String
    fingerprint_algorithm::String
    source_model_artifact::String
    source_model_sha256::String
    model_artifact::String
    model_artifact_sha256::String
    vp_id::String
    contract_id::String
    lean_decl::String
    checker_id::String
    checker_relation::String
    checker_source::String
    checker_source_sha256::String
    checker_version::String
    adapter_id::String
    adapter_source_origin::String
    adapter_source::String
    adapter_source_sha256::String
    adapter_version::String
    registry_snapshot::String
    registry_snapshot_sha256::String
    outcome::Symbol
    failed_predicates::Vector{String}
    claim_relation::Symbol
    error_message::Union{String,Nothing}
    seed::Union{Int,Nothing}
    numeric_assumptions::NamedTuple
    git_commit::String
    git_dirty::Bool
    julia_version::String
    manifest_sha256::String
    log_path::String
    log_sha256::String
    generated_unix::Float64
    phenomenal_claim::Symbol
end

_model_evaluation_sha256(bytes::AbstractVector{UInt8}) = bytes2hex(SHA.sha256(bytes))
_model_evaluation_sha256(text::AbstractString) =
    _model_evaluation_sha256(Vector{UInt8}(codeunits(text)))
_model_evaluation_sha256_file(path::AbstractString) =
    _model_evaluation_sha256(read(path))

function _model_evaluation_relative_path(value::AbstractString, field::AbstractString)
    path = String(value)
    isempty(path) && throw(ArgumentError("$field must be nonempty"))
    isabspath(path) && throw(ArgumentError("$field must be repository-relative"))
    normalized = normpath(path)
    parts = splitpath(normalized)
    (!isempty(parts) && first(parts) == "..") &&
        throw(ArgumentError("$field must stay inside the evidence root"))
    normalized
end

function _model_evaluation_project_file(
    project_root::AbstractString,
    relative_path::AbstractString,
    field::AbstractString,
)
    relative = _model_evaluation_relative_path(relative_path, field)
    candidate = joinpath(project_root, relative)
    isfile(candidate) || throw(ArgumentError("$field is missing"))
    actual = realpath(candidate)
    project = realpath(project_root)
    (actual == project || startswith(actual, project * string(Base.Filesystem.path_separator))) ||
        throw(ArgumentError("$field must stay inside the project root"))
    (; relative, actual)
end

function _model_evaluation_secure_directory(
    root::AbstractString,
    components::AbstractString...,
)
    mkpath(root)
    canonical_root = realpath(root)
    current = canonical_root
    for component in components
        isempty(component) && throw(ArgumentError("directory component must be nonempty"))
        occursin(Base.Filesystem.path_separator, component) &&
            throw(ArgumentError("directory component must not contain a path separator"))
        candidate = joinpath(current, component)
        islink(candidate) && throw(ArgumentError(
            "evidence directory components must not be symlinks: $component",
        ))
        ispath(candidate) && !isdir(candidate) &&
            throw(ArgumentError("evidence directory component is not a directory: $component"))
        mkpath(candidate)
        actual = realpath(candidate)
        startswith(actual, canonical_root * string(Base.Filesystem.path_separator)) ||
            throw(ArgumentError("evidence directory escapes its root"))
        current = actual
    end
    current
end

function _model_evaluation_existing_directory(
    root::AbstractString,
    components::AbstractString...,
)
    isdir(root) || return nothing
    canonical_root = realpath(root)
    current = canonical_root
    for component in components
        candidate = joinpath(current, component)
        islink(candidate) && throw(ArgumentError(
            "evidence directory components must not be symlinks: $component",
        ))
        !ispath(candidate) && return nothing
        isdir(candidate) || throw(ArgumentError(
            "evidence directory component is not a directory: $component",
        ))
        actual = realpath(candidate)
        startswith(actual, canonical_root * string(Base.Filesystem.path_separator)) ||
            throw(ArgumentError("evidence directory escapes its root"))
        current = actual
    end
    current
end

function _model_evaluation_hash(value::AbstractString, field::AbstractString)
    hash = String(value)
    occursin(_MODEL_EVALUATION_SHA256, hash) ||
        throw(ArgumentError("$field must be a lowercase SHA-256 digest"))
    hash
end

function _model_evaluation_json_safe(value, field::AbstractString="numeric_assumptions")
    if value === nothing || value isa Bool || value isa AbstractString || value isa Symbol ||
            value isa Integer
        return true
    elseif value isa AbstractFloat
        isfinite(value) || throw(ArgumentError("$field must contain only finite numbers"))
        return true
    elseif value isa NamedTuple
        for (name, item) in pairs(value)
            _model_evaluation_json_safe(item, "$field.$name")
        end
        return true
    elseif value isa AbstractVector || value isa Tuple
        for (index, item) in pairs(value)
            _model_evaluation_json_safe(item, "$field[$index]")
        end
        return true
    end
    throw(ArgumentError("$field contains an unsupported JSON value: $(typeof(value))"))
end

function ModelEvaluationRecord(;
    evaluation_id::AbstractString,
    model_fingerprint::AbstractString,
    fingerprint_algorithm::AbstractString,
    source_model_artifact::AbstractString,
    source_model_sha256::AbstractString,
    model_artifact::AbstractString,
    model_artifact_sha256::AbstractString,
    vp_id::AbstractString,
    contract_id::AbstractString,
    lean_decl::AbstractString,
    checker_id::AbstractString,
    checker_relation::AbstractString,
    checker_source::AbstractString,
    checker_source_sha256::AbstractString,
    checker_version::AbstractString,
    adapter_id::AbstractString,
    adapter_source_origin::AbstractString,
    adapter_source::AbstractString,
    adapter_source_sha256::AbstractString,
    adapter_version::AbstractString,
    registry_snapshot::AbstractString,
    registry_snapshot_sha256::AbstractString,
    outcome::Symbol,
    failed_predicates=String[],
    claim_relation::Symbol=:observation_only,
    error_message::Union{AbstractString,Nothing}=nothing,
    seed::Union{Integer,Nothing}=nothing,
    numeric_assumptions::NamedTuple=NamedTuple(),
    git_commit::AbstractString,
    git_dirty::Bool,
    julia_version::AbstractString=string(VERSION),
    manifest_sha256::AbstractString,
    log_path::AbstractString,
    log_sha256::AbstractString,
    generated_unix::Real=time(),
    phenomenal_claim::Symbol=:not_certified,
)
    id = _model_evaluation_valid_id(evaluation_id)
    outcome in _MODEL_EVALUATION_OUTCOMES ||
        throw(ArgumentError("outcome must be pass, reject, or error"))
    claim_relation in _MODEL_EVALUATION_CLAIM_RELATIONS ||
        throw(ArgumentError(
            "claim_relation must be observation_only or counterexample_candidate",
        ))
    predicates = String[String(predicate) for predicate in failed_predicates]
    any(isempty, predicates) &&
        throw(ArgumentError("failed_predicates must not contain empty names"))
    outcome == :pass && !isempty(predicates) &&
        throw(ArgumentError("pass evaluations cannot have failed_predicates"))
    outcome == :reject && isempty(predicates) &&
        throw(ArgumentError("reject evaluations require at least one failed predicate"))
    outcome == :error && !isempty(predicates) &&
        throw(ArgumentError("error is not predicate rejection; failed_predicates must be empty"))
    claim_relation == :counterexample_candidate && outcome != :reject &&
        throw(ArgumentError("only reject evaluations can be counterexample candidates"))
    message = error_message === nothing ? nothing : String(error_message)
    outcome == :error && (message === nothing || isempty(message)) &&
        throw(ArgumentError("error evaluations require error_message"))
    outcome != :error && message !== nothing &&
        throw(ArgumentError("only error evaluations may have error_message"))
    phenomenal_claim == :not_certified ||
        throw(ArgumentError("phenomenal_claim must remain :not_certified"))
    isfinite(generated_unix) || throw(ArgumentError("generated_unix must be finite"))
    _model_evaluation_json_safe(numeric_assumptions)

    strings = (
        model_fingerprint=String(model_fingerprint),
        fingerprint_algorithm=String(fingerprint_algorithm),
        vp_id=String(vp_id),
        contract_id=String(contract_id),
        lean_decl=String(lean_decl),
        checker_id=String(checker_id),
        checker_relation=String(checker_relation),
        checker_version=String(checker_version),
        adapter_id=String(adapter_id),
        adapter_version=String(adapter_version),
        git_commit=String(git_commit),
        julia_version=String(julia_version),
    )
    for (field, value) in pairs(strings)
        isempty(value) && throw(ArgumentError("$(field) must be nonempty"))
    end
    startswith(strings.model_fingerprint, "sha256:") ||
        throw(ArgumentError("model_fingerprint must use a sha256: prefix"))
    _model_evaluation_hash(strings.model_fingerprint[8:end], "model_fingerprint")

    ModelEvaluationRecord(
        MODEL_EVALUATION_SCHEMA_VERSION,
        id,
        strings.model_fingerprint,
        strings.fingerprint_algorithm,
        _model_evaluation_relative_path(source_model_artifact, "source_model_artifact"),
        _model_evaluation_hash(source_model_sha256, "source_model_sha256"),
        _model_evaluation_relative_path(model_artifact, "model_artifact"),
        _model_evaluation_hash(model_artifact_sha256, "model_artifact_sha256"),
        strings.vp_id,
        strings.contract_id,
        strings.lean_decl,
        strings.checker_id,
        strings.checker_relation,
        _model_evaluation_relative_path(checker_source, "checker_source"),
        _model_evaluation_hash(checker_source_sha256, "checker_source_sha256"),
        strings.checker_version,
        strings.adapter_id,
        _model_evaluation_relative_path(adapter_source_origin, "adapter_source_origin"),
        _model_evaluation_relative_path(adapter_source, "adapter_source"),
        _model_evaluation_hash(adapter_source_sha256, "adapter_source_sha256"),
        strings.adapter_version,
        _model_evaluation_relative_path(registry_snapshot, "registry_snapshot"),
        _model_evaluation_hash(registry_snapshot_sha256, "registry_snapshot_sha256"),
        outcome,
        predicates,
        claim_relation,
        message,
        seed === nothing ? nothing : Int(seed),
        numeric_assumptions,
        strings.git_commit,
        git_dirty,
        strings.julia_version,
        _model_evaluation_hash(manifest_sha256, "manifest_sha256"),
        _model_evaluation_relative_path(log_path, "log_path"),
        _model_evaluation_hash(log_sha256, "log_sha256"),
        Float64(generated_unix),
        phenomenal_claim,
    )
end

function model_evaluation_payload(record::ModelEvaluationRecord)
    (
        kind=:model_evaluation,
        schema_version=record.schema_version,
        evaluation_id=record.evaluation_id,
        model_fingerprint=record.model_fingerprint,
        fingerprint_algorithm=record.fingerprint_algorithm,
        source_model_artifact=record.source_model_artifact,
        source_model_sha256=record.source_model_sha256,
        model_artifact=record.model_artifact,
        model_artifact_sha256=record.model_artifact_sha256,
        vp_id=record.vp_id,
        contract_id=record.contract_id,
        lean_decl=record.lean_decl,
        checker_id=record.checker_id,
        checker_relation=record.checker_relation,
        checker_source=record.checker_source,
        checker_source_sha256=record.checker_source_sha256,
        checker_version=record.checker_version,
        adapter_id=record.adapter_id,
        adapter_source_origin=record.adapter_source_origin,
        adapter_source=record.adapter_source,
        adapter_source_sha256=record.adapter_source_sha256,
        adapter_version=record.adapter_version,
        registry_snapshot=record.registry_snapshot,
        registry_snapshot_sha256=record.registry_snapshot_sha256,
        outcome=record.outcome,
        failed_predicates=record.failed_predicates,
        claim_relation=record.claim_relation,
        claim_status=:not_a_claim,
        error_message=record.error_message,
        seed=record.seed,
        numeric_assumptions=record.numeric_assumptions,
        git_commit=record.git_commit,
        git_dirty=record.git_dirty,
        julia_version=record.julia_version,
        manifest_sha256=record.manifest_sha256,
        log_path=record.log_path,
        log_sha256=record.log_sha256,
        generated_unix=record.generated_unix,
        phenomenal_claim=record.phenomenal_claim,
        julia_unverified_execution_boundary(
            note="A model evaluation records a Julia checker execution; it is not a Lean proof or a certified counterexample claim.",
        )...,
    )
end


model_evaluation_json(record::ModelEvaluationRecord) =
    String(JSON3.write(model_evaluation_payload(record)))

model_evaluation_path(root::AbstractString, evaluation_id::AbstractString) = joinpath(
    root,
    "logs",
    "model-evaluations",
    _model_evaluation_valid_id(evaluation_id),
    "evaluation.json",
)

function _model_evaluation_plain(value)
    if value isa JSON3.Object
        names = Symbol[]
        values = Any[]
        for (key, item) in pairs(value)
            push!(names, Symbol(String(key)))
            push!(values, _model_evaluation_plain(item))
        end
        return NamedTuple{Tuple(names)}(Tuple(values))
    elseif value isa JSON3.Array
        return [_model_evaluation_plain(item) for item in value]
    end
    value
end

function parse_model_evaluation_json(text::AbstractString)
    payload = JSON3.read(text)
    payload isa JSON3.Object ||
        throw(ArgumentError("model evaluation artifact must be a JSON object"))
    raw_keys = String[String(key) for key in keys(payload)]
    length(raw_keys) == length(unique(raw_keys)) ||
        throw(ArgumentError("duplicate model evaluation fields are forbidden"))
    actual_keys = Set(raw_keys)
    actual_keys == _MODEL_EVALUATION_PAYLOAD_KEYS || begin
        missing = sort!(collect(setdiff(_MODEL_EVALUATION_PAYLOAD_KEYS, actual_keys)))
        unknown = sort!(collect(setdiff(actual_keys, _MODEL_EVALUATION_PAYLOAD_KEYS)))
        isempty(missing) ||
            throw(ArgumentError("missing model evaluation fields: $(join(missing, ", "))"))
        throw(ArgumentError("unknown model evaluation fields: $(join(unknown, ", "))"))
    end
    String(payload.kind) == "model_evaluation" ||
        throw(ArgumentError("artifact kind must be model_evaluation"))
    Int(payload.schema_version) == MODEL_EVALUATION_SCHEMA_VERSION ||
        throw(ArgumentError("unsupported model evaluation schema version"))
    String(payload.claim_status) == "not_a_claim" ||
        throw(ArgumentError("claim_status must be not_a_claim"))
    String(payload.execution_layer) == "julia_unverified" ||
        throw(ArgumentError("execution_layer must be julia_unverified"))
    payload.execution_certified === false ||
        throw(ArgumentError("execution_certified must be false"))
    String(payload.execution_boundary) == "unverified_runtime" ||
        throw(ArgumentError("execution_boundary must be unverified_runtime"))
    numeric = _model_evaluation_plain(payload.numeric_assumptions)
    numeric isa NamedTuple || throw(ArgumentError("numeric_assumptions must be an object"))
    ModelEvaluationRecord(
        evaluation_id=String(payload.evaluation_id),
        model_fingerprint=String(payload.model_fingerprint),
        fingerprint_algorithm=String(payload.fingerprint_algorithm),
        source_model_artifact=String(payload.source_model_artifact),
        source_model_sha256=String(payload.source_model_sha256),
        model_artifact=String(payload.model_artifact),
        model_artifact_sha256=String(payload.model_artifact_sha256),
        vp_id=String(payload.vp_id),
        contract_id=String(payload.contract_id),
        lean_decl=String(payload.lean_decl),
        checker_id=String(payload.checker_id),
        checker_relation=String(payload.checker_relation),
        checker_source=String(payload.checker_source),
        checker_source_sha256=String(payload.checker_source_sha256),
        checker_version=String(payload.checker_version),
        adapter_id=String(payload.adapter_id),
        adapter_source_origin=String(payload.adapter_source_origin),
        adapter_source=String(payload.adapter_source),
        adapter_source_sha256=String(payload.adapter_source_sha256),
        adapter_version=String(payload.adapter_version),
        registry_snapshot=String(payload.registry_snapshot),
        registry_snapshot_sha256=String(payload.registry_snapshot_sha256),
        outcome=Symbol(String(payload.outcome)),
        failed_predicates=String[String(item) for item in payload.failed_predicates],
        claim_relation=Symbol(String(payload.claim_relation)),
        error_message=payload.error_message === nothing ? nothing : String(payload.error_message),
        seed=payload.seed === nothing ? nothing : Int(payload.seed),
        numeric_assumptions=numeric,
        git_commit=String(payload.git_commit),
        git_dirty=Bool(payload.git_dirty),
        julia_version=String(payload.julia_version),
        manifest_sha256=String(payload.manifest_sha256),
        log_path=String(payload.log_path),
        log_sha256=String(payload.log_sha256),
        generated_unix=Float64(payload.generated_unix),
        phenomenal_claim=Symbol(String(payload.phenomenal_claim)),
    )
end

read_model_evaluation(path::AbstractString) =
    parse_model_evaluation_json(read(path, String))

function _model_evaluation_registry_binding(
    project_root::AbstractString,
    vp_id::AbstractString,
    contract_id::AbstractString,
    checker_id::AbstractString,
)
    ledger_path = joinpath(project_root, "specs", "ledger.toml")
    ledger = TOML.parsefile(ledger_path)
    vps = filter(vp -> String(vp["id"]) == vp_id, ledger["vp"])
    length(vps) == 1 || throw(ArgumentError("unknown or duplicate VP id: $vp_id"))
    vp = only(vps)
    String(vp["status"]) == "certified" ||
        throw(ArgumentError("model evaluation requires a certified VP binding"))
    String(vp["contract_id"]) == contract_id ||
        throw(ArgumentError("contract_id does not match VP binding"))
    String(vp["julia_api"]) == checker_id ||
        throw(ArgumentError("checker_id does not match VP binding"))

    manifest_path = joinpath(project_root, "specs", "checker-semantic-manifest.toml")
    manifest = TOML.parsefile(manifest_path)
    contracts = filter(row -> String(row["id"]) == contract_id, manifest["contract"])
    length(contracts) == 1 ||
        throw(ArgumentError("unknown or duplicate semantic contract: $contract_id"))
    semantic = only(contracts)
    String(semantic["checker"]) == checker_id ||
        throw(ArgumentError("semantic manifest checker does not match VP binding"))
    String(semantic["lean_decl"]) == String(vp["lean_decl"]) ||
        throw(ArgumentError("semantic manifest Lean declaration does not match VP binding"))
    String(semantic["review_status"]) == "reviewed" ||
        throw(ArgumentError("semantic contract must be reviewed"))

    catalog_source = joinpath(project_root, "formal", "ERIEC", "CertifiedArtifact.lean")
    catalog_key = (
        realpath(project_root),
        isfile(catalog_source) ? _model_evaluation_sha256_file(catalog_source) : "missing",
    )
    artifact = lock(_MODEL_EVALUATION_CATALOG_LOCK) do
        get!(_MODEL_EVALUATION_CATALOG_CACHE, catalog_key) do
            lean_certified_artifact(; project_root=project_root)
        end
    end
    catalog = filter(contract -> contract.id == contract_id, artifact.contracts)
    length(catalog) == 1 || throw(ArgumentError("contract is absent from certificate catalog"))
    certified = only(catalog)
    certified.lean_full_name == String(vp["lean_decl"]) ||
        throw(ArgumentError("certificate catalog Lean declaration does not match VP binding"))
    certified.julia_checker == Symbol(checker_id) ||
        throw(ArgumentError("certificate catalog checker does not match VP binding"))
    verification_key = (realpath(project_root), catalog_key[2], String(contract_id))
    lock(_MODEL_EVALUATION_CATALOG_LOCK) do
        if !(verification_key in _MODEL_EVALUATION_VERIFIED_CONTRACT_CACHE)
            isempty(_missing_lean_full_names(project_root, [certified])) ||
                throw(ArgumentError("catalog Lean declaration does not resolve"))
            push!(_MODEL_EVALUATION_VERIFIED_CONTRACT_CACHE, verification_key)
        end
    end
    isdefined(@__MODULE__, Symbol(checker_id)) ||
        throw(ArgumentError("checker is not defined in ERIEC"))

    checker_source = _model_evaluation_project_file(
        project_root,
        String(vp["julia_file"]),
        "ledger julia_file",
    )
    (
        vp_id=String(vp_id),
        contract_id=String(contract_id),
        lean_decl=String(vp["lean_decl"]),
        checker_id=String(checker_id),
        checker_relation=String(semantic["checker_relation"]),
        checker_source=checker_source.relative,
        scope=String(semantic["scope"]),
        assumptions=String[String(item) for item in semantic["assumptions"]],
        guarantee=String(semantic["guarantee"]),
        catalog_artifact_id=artifact.artifact_id,
        catalog_version=artifact.version,
        ledger_sha256=_model_evaluation_sha256_file(ledger_path),
        semantic_manifest_sha256=_model_evaluation_sha256_file(manifest_path),
        certified_artifact_source_sha256=catalog_key[2],
    )
end

function _model_evaluation_registry_payload(binding)
    (
        kind=:model_evaluation_registry_snapshot,
        vp_id=binding.vp_id,
        contract_id=binding.contract_id,
        lean_decl=binding.lean_decl,
        checker_id=binding.checker_id,
        checker_relation=binding.checker_relation,
        checker_source=binding.checker_source,
        scope=binding.scope,
        assumptions=binding.assumptions,
        guarantee=binding.guarantee,
        catalog_artifact_id=binding.catalog_artifact_id,
        catalog_version=binding.catalog_version,
        ledger_sha256=binding.ledger_sha256,
        semantic_manifest_sha256=binding.semantic_manifest_sha256,
        certified_artifact_source_sha256=binding.certified_artifact_source_sha256,
    )
end

function _model_evaluation_git_state(project_root::AbstractString)
    commit = try
        readchomp(Cmd(`git rev-parse HEAD`; dir=project_root))
    catch
        "unavailable"
    end
    dirty = try
        !isempty(readchomp(Cmd(`git status --porcelain`; dir=project_root)))
    catch
        true
    end
    (; commit, dirty)
end

function _model_evaluation_error_text(err, backtrace)
    io = IOBuffer()
    showerror(io, err, backtrace)
    String(take!(io))
end

function _model_evaluation_id(vp_id::AbstractString, canonical_bytes::AbstractVector{UInt8})
    digest = _model_evaluation_sha256(canonical_bytes)
    lock(_MODEL_EVALUATION_ID_LOCK) do
        _MODEL_EVALUATION_ID_COUNTER[] += 1
        "$(vp_id)-$(time_ns())-$(getpid())-$(_MODEL_EVALUATION_ID_COUNTER[])-$(digest[1:12])"
    end
end

"""Run a checker and atomically persist pass/reject/error plus self-contained snapshots."""
function _run_model_evaluation(
    project_root::AbstractString;
    output_root::AbstractString=project_root,
    evaluation_id::Union{AbstractString,Nothing}=nothing,
    raw_model_bytes::AbstractVector{UInt8},
    prepare_model::Function,
    vp_id::AbstractString,
    contract_id::AbstractString,
    checker_id::AbstractString,
    failed_predicates_on_reject,
    adapter_id::AbstractString,
    adapter_source::AbstractString,
    claim_relation::Symbol=:observation_only,
    seed::Union{Integer,Nothing}=nothing,
    numeric_assumptions::NamedTuple=NamedTuple(),
)
    project = realpath(project_root)
    output = realpath(mkpath(abspath(output_root)))
    binding = _model_evaluation_registry_binding(project, vp_id, contract_id, checker_id)
    claim_relation in _MODEL_EVALUATION_CLAIM_RELATIONS || throw(ArgumentError(
        "claim_relation must be observation_only or counterexample_candidate",
    ))
    configured_failed_predicates = String[
        String(item) for item in failed_predicates_on_reject
    ]
    configured_failed_predicates == [binding.lean_decl] || throw(ArgumentError(
        "failed_predicates_on_reject must equal the registry-bound Lean declaration",
    ))
    normalized_adapter_id = _model_evaluation_valid_id(adapter_id)
    adapter_file = _model_evaluation_project_file(
        project,
        adapter_source,
        "adapter_source",
    )
    checker_source_bytes = read(joinpath(project, binding.checker_source))
    adapter_source_bytes = read(adapter_file.actual)
    loaded_checker_sha = get(
        _MODEL_EVALUATION_LOADED_SOURCE_SHA256,
        binding.checker_source,
        nothing,
    )
    loaded_adapter_sha = get(
        _MODEL_EVALUATION_LOADED_SOURCE_SHA256,
        adapter_file.relative,
        nothing,
    )
    loaded_checker_sha == _model_evaluation_sha256(checker_source_bytes) ||
        throw(ArgumentError("checker source changed after ERIEC was loaded; restart Julia"))
    loaded_adapter_sha == _model_evaluation_sha256(adapter_source_bytes) ||
        throw(ArgumentError("adapter source changed after ERIEC was loaded; restart Julia"))
    registered_checker = getfield(@__MODULE__, Symbol(binding.checker_id))
    registered_checker isa Function ||
        throw(ArgumentError("registered checker is not callable"))
    claim_relation == :counterexample_candidate &&
        binding.checker_relation != "exact_finite_decision" &&
        throw(ArgumentError(
            "counterexample candidates require a reviewed exact_finite_decision checker",
        ))
    _model_evaluation_json_safe(numeric_assumptions)
    raw_bytes = Vector{UInt8}(raw_model_bytes)

    prepared = nothing
    canonical_bytes = raw_bytes
    fingerprint_algorithm = MODEL_EVALUATION_RAW_FINGERPRINT_ALGORITHM
    outcome = :error
    error_message = nothing
    capture_path, capture_io = mktemp()
    try
        prepared = prepare_model(raw_bytes)
        hasproperty(prepared, :canonical_bytes) ||
            throw(ArgumentError("prepare_model must return canonical_bytes"))
        hasproperty(prepared, :value) ||
            throw(ArgumentError("prepare_model must return value"))
        canonical_bytes = Vector{UInt8}(prepared.canonical_bytes)
        isempty(canonical_bytes) && throw(ArgumentError("canonical model must be nonempty"))
        fingerprint_algorithm = hasproperty(prepared, :fingerprint_algorithm) ?
            String(prepared.fingerprint_algorithm) : MODEL_EVALUATION_FINGERPRINT_ALGORITHM
        result = lock(_MODEL_EVALUATION_CHECKER_LOCK) do
            redirect_stdout(capture_io) do
                redirect_stderr(capture_io) do
                    registered_checker(prepared.value)
                end
            end
        end
        result isa Bool || throw(ArgumentError("model checker must return Bool"))
        outcome = result ? :pass : :reject
    catch err
        error_message = _model_evaluation_error_text(err, catch_backtrace())
        outcome = :error
    finally
        close(capture_io)
    end
    try
        _model_evaluation_sha256_file(joinpath(project, binding.checker_source)) ==
            _model_evaluation_sha256(checker_source_bytes) ||
            throw(ArgumentError("checker source changed during execution"))
        _model_evaluation_sha256_file(adapter_file.actual) ==
            _model_evaluation_sha256(adapter_source_bytes) ||
            throw(ArgumentError("adapter source changed during execution"))
    catch err
        error_message = _model_evaluation_error_text(err, catch_backtrace())
        outcome = :error
    end
    captured = read(capture_path)
    rm(capture_path)
    log_buffer = IOBuffer()
    write(log_buffer, captured)
    error_message === nothing || println(log_buffer, "\nchecker_error=", error_message)
    println(log_buffer, "outcome=", outcome)
    log_bytes = take!(log_buffer)

    id = _model_evaluation_valid_id(evaluation_id === nothing ?
        _model_evaluation_id(vp_id, canonical_bytes) : String(evaluation_id))
    parent = _model_evaluation_secure_directory(output, "logs", "model-evaluations")
    destination = joinpath(parent, id)
    ispath(destination) && throw(ArgumentError(
        "evaluation_id already exists; model evaluations are create-only",
    ))

    registry_bytes = Vector{UInt8}(codeunits(
        String(JSON3.write(_model_evaluation_registry_payload(binding))) * "\n",
    ))
    git = _model_evaluation_git_state(project)
    manifest_path = joinpath(project, "Manifest.toml")
    manifest_sha = isfile(manifest_path) ?
        _model_evaluation_sha256_file(manifest_path) : _model_evaluation_sha256(UInt8[])
    base_relative = joinpath("logs", "model-evaluations", id)
    source_relative = joinpath(base_relative, "source-model.json")
    model_relative = joinpath(base_relative, "model.json")
    checker_relative = joinpath(base_relative, "checker-source.jl")
    adapter_relative = joinpath(base_relative, "adapter-source.jl")
    registry_relative = joinpath(base_relative, "registry.json")
    log_relative = joinpath(base_relative, "checker.log")
    model_sha = _model_evaluation_sha256(canonical_bytes)
    actual_claim_relation = outcome == :reject ? claim_relation : :observation_only
    failed = outcome == :reject ? configured_failed_predicates : String[]
    record = ModelEvaluationRecord(
        evaluation_id=id,
        model_fingerprint="sha256:$model_sha",
        fingerprint_algorithm=fingerprint_algorithm,
        source_model_artifact=source_relative,
        source_model_sha256=_model_evaluation_sha256(raw_bytes),
        model_artifact=model_relative,
        model_artifact_sha256=model_sha,
        vp_id=binding.vp_id,
        contract_id=binding.contract_id,
        lean_decl=binding.lean_decl,
        checker_id=binding.checker_id,
        checker_relation=binding.checker_relation,
        checker_source=checker_relative,
        checker_source_sha256=_model_evaluation_sha256(checker_source_bytes),
        checker_version="sha256:$(_model_evaluation_sha256(checker_source_bytes))",
        adapter_id=normalized_adapter_id,
        adapter_source_origin=adapter_file.relative,
        adapter_source=adapter_relative,
        adapter_source_sha256=_model_evaluation_sha256(adapter_source_bytes),
        adapter_version="sha256:$(_model_evaluation_sha256(adapter_source_bytes))",
        registry_snapshot=registry_relative,
        registry_snapshot_sha256=_model_evaluation_sha256(registry_bytes),
        outcome=outcome,
        failed_predicates=failed,
        claim_relation=actual_claim_relation,
        error_message=error_message,
        seed=seed,
        numeric_assumptions=numeric_assumptions,
        git_commit=git.commit,
        git_dirty=git.dirty,
        manifest_sha256=manifest_sha,
        log_path=log_relative,
        log_sha256=_model_evaluation_sha256(log_bytes),
        phenomenal_claim=:not_certified,
    )

    temporary = mktempdir(parent; prefix=".pending-")
    try
        write(joinpath(temporary, "source-model.json"), raw_bytes)
        write(joinpath(temporary, "model.json"), canonical_bytes)
        write(joinpath(temporary, "checker-source.jl"), checker_source_bytes)
        write(joinpath(temporary, "adapter-source.jl"), adapter_source_bytes)
        write(joinpath(temporary, "registry.json"), registry_bytes)
        write(joinpath(temporary, "checker.log"), log_bytes)
        evaluation_bytes = Vector{UInt8}(codeunits(model_evaluation_json(record) * "\n"))
        write(joinpath(temporary, "evaluation.json"), evaluation_bytes)
        seal = _model_evaluation_sha256(evaluation_bytes)
        write(joinpath(temporary, "seal.sha256"), "$seal  evaluation.json\n")
        mv(temporary, destination)
    catch
        ispath(temporary) && rm(temporary; recursive=true)
        rethrow()
    end
    (record=record, path=joinpath(destination, "evaluation.json"))
end

function _model_evaluation_safe_snapshot(
    evidence_root::AbstractString,
    evaluation_directory::AbstractString,
    relative_path::AbstractString,
)
    try
        candidate = joinpath(
            evidence_root,
            _model_evaluation_relative_path(relative_path, "snapshot"),
        )
        isfile(candidate) || return nothing
        actual = realpath(candidate)
        directory = realpath(evaluation_directory)
        (actual == directory ||
            startswith(actual, directory * string(Base.Filesystem.path_separator))) ||
            return nothing
        actual
    catch
        nothing
    end
end

"""Audit one evaluation without throwing; current registry drift is a warning."""
function audit_model_evaluation(
    evidence_root::AbstractString,
    evaluation_id::AbstractString;
    project_root::AbstractString=evidence_root,
)
    errors = String[]
    warnings = String[]
    record = nothing
    kind = :model_evaluation_audit_entry
    id = String(evaluation_id)
    if !occursin(_MODEL_EVALUATION_ID, id)
        push!(errors, "invalid evaluation id")
        return (; kind, ok=false, evaluation_id=id, errors, warnings, record)
    end
    path = model_evaluation_path(evidence_root, id)
    directory = dirname(path)
    if !isfile(path)
        push!(errors, "evaluation.json is missing")
        return (; kind, ok=false, evaluation_id=id, errors, warnings, record)
    end
    try
        evidence = realpath(evidence_root)
        actual_directory = realpath(directory)
        startswith(actual_directory, evidence * string(Base.Filesystem.path_separator)) ||
            push!(errors, "evaluation directory escapes the evidence root")
        islink(directory) && push!(errors, "evaluation directory must not be a symlink")
    catch err
        push!(errors, "evaluation directory validation failed: $(sprint(showerror, err))")
    end
    try
        record = read_model_evaluation(path)
    catch err
        push!(errors, "evaluation parse failed: $(sprint(showerror, err))")
        return (; kind, ok=false, evaluation_id=id, errors, warnings, record)
    end
    record.evaluation_id == evaluation_id || push!(errors, "directory id does not match record")

    seal_path = joinpath(directory, "seal.sha256")
    if !isfile(seal_path)
        push!(errors, "seal.sha256 is missing")
    else
        try
            seal_fields = split(strip(read(seal_path, String)))
            length(seal_fields) == 2 && seal_fields[2] == "evaluation.json" ||
                throw(ArgumentError("invalid seal format"))
            expected = _model_evaluation_hash(seal_fields[1], "evaluation seal")
            actual = _model_evaluation_sha256_file(path)
            expected == actual || push!(errors, "evaluation seal mismatch")
        catch err
            push!(errors, "evaluation seal validation failed: $(sprint(showerror, err))")
        end
    end

    snapshots = (
        source_model=(record.source_model_artifact, record.source_model_sha256),
        model=(record.model_artifact, record.model_artifact_sha256),
        checker=(record.checker_source, record.checker_source_sha256),
        adapter=(record.adapter_source, record.adapter_source_sha256),
        registry=(record.registry_snapshot, record.registry_snapshot_sha256),
        log=(record.log_path, record.log_sha256),
    )
    resolved_snapshots = Dict{Symbol,String}()
    for (name, (relative, expected)) in pairs(snapshots)
        snapshot = _model_evaluation_safe_snapshot(evidence_root, directory, relative)
        if snapshot === nothing
            push!(errors, "$name snapshot is missing or escapes its evaluation directory")
        else
            resolved_snapshots[name] = snapshot
            try
                _model_evaluation_sha256_file(snapshot) == expected ||
                    push!(errors, "$name snapshot hash mismatch")
            catch err
                push!(errors, "$name snapshot read failed: $(sprint(showerror, err))")
            end
        end
    end
    record.model_fingerprint == "sha256:$(record.model_artifact_sha256)" ||
        push!(errors, "model fingerprint is not bound to canonical model bytes")
    record.checker_version == "sha256:$(record.checker_source_sha256)" ||
        push!(errors, "checker version is not bound to checker source bytes")
    record.adapter_version == "sha256:$(record.adapter_source_sha256)" ||
        push!(errors, "adapter version is not bound to adapter source bytes")
    if haskey(resolved_snapshots, :model) && haskey(resolved_snapshots, :adapter)
        loaded_adapter_sha = get(
            _MODEL_EVALUATION_LOADED_SOURCE_SHA256,
            record.adapter_source_origin,
            nothing,
        )
        loaded_checker_sha = record.checker_id == "check_m4_no_terminal_setpoint" ?
            get(_MODEL_EVALUATION_LOADED_SOURCE_SHA256, "src/body.jl", nothing) : nothing
        if loaded_adapter_sha == record.adapter_source_sha256 &&
                loaded_checker_sha == record.checker_source_sha256
            try
                append!(
                    errors,
                    _audit_model_evaluation_adapter(record, resolved_snapshots[:model]),
                )
            catch err
                push!(errors, "adapter audit failed: $(sprint(showerror, err))")
            end
        else
            push!(warnings, "semantic replay skipped because loaded checker/adapter drifted")
        end
    end

    if isempty(errors)
        try
            registry = JSON3.read(read(resolved_snapshots[:registry], String))
            registry isa JSON3.Object ||
                throw(ArgumentError("registry snapshot must be a JSON object"))
            registry_keys = String[String(key) for key in keys(registry)]
            length(registry_keys) == length(unique(registry_keys)) ||
                throw(ArgumentError("duplicate registry snapshot fields are forbidden"))
            Set(registry_keys) == _MODEL_EVALUATION_REGISTRY_KEYS ||
                throw(ArgumentError("registry snapshot fields do not match the schema"))
            String(registry.vp_id) == record.vp_id ||
                push!(errors, "registry snapshot VP mismatch")
            String(registry.contract_id) == record.contract_id ||
                push!(errors, "registry snapshot contract mismatch")
            String(registry.checker_id) == record.checker_id ||
                push!(errors, "registry snapshot checker mismatch")
            String(registry.checker_relation) == record.checker_relation ||
                push!(errors, "registry snapshot checker relation mismatch")
            String(registry.lean_decl) == record.lean_decl ||
                push!(errors, "registry snapshot Lean declaration mismatch")
            String(registry.kind) == "model_evaluation_registry_snapshot" ||
                push!(errors, "registry snapshot kind mismatch")
            _model_evaluation_relative_path(
                String(registry.checker_source),
                "registry checker_source",
            )
            isempty(String(registry.scope)) &&
                throw(ArgumentError("registry scope must be nonempty"))
            registry.assumptions isa JSON3.Array ||
                throw(ArgumentError("registry assumptions must be an array"))
            all(item -> item isa AbstractString, registry.assumptions) ||
                throw(ArgumentError("registry assumptions must contain strings"))
            isempty(String(registry.guarantee)) &&
                throw(ArgumentError("registry guarantee must be nonempty"))
            isempty(String(registry.catalog_artifact_id)) &&
                throw(ArgumentError("registry catalog id must be nonempty"))
            registry.catalog_version isa Integer &&
                !(registry.catalog_version isa Bool) ||
                throw(ArgumentError("registry catalog version must be an integer"))
            _model_evaluation_hash(String(registry.ledger_sha256), "registry ledger_sha256")
            _model_evaluation_hash(
                String(registry.semantic_manifest_sha256),
                "registry semantic_manifest_sha256",
            )
            _model_evaluation_hash(
                String(registry.certified_artifact_source_sha256),
                "registry certified_artifact_source_sha256",
            )
        catch err
            push!(errors, "registry snapshot parse failed: $(sprint(showerror, err))")
        end
    end
    try
        current = _model_evaluation_registry_binding(
            realpath(project_root),
            record.vp_id,
            record.contract_id,
            record.checker_id,
        )
        current.lean_decl == record.lean_decl || push!(warnings, "current Lean binding drifted")
        current.checker_relation == record.checker_relation ||
            push!(warnings, "current checker relation drifted")
        current_registry_bytes = Vector{UInt8}(codeunits(
            String(JSON3.write(_model_evaluation_registry_payload(current))) * "\n",
        ))
        _model_evaluation_sha256(current_registry_bytes) == record.registry_snapshot_sha256 ||
            push!(warnings, "current registry snapshot drifted")
        current_checker_sha = _model_evaluation_sha256_file(
            joinpath(realpath(project_root), current.checker_source),
        )
        current_checker_sha == record.checker_source_sha256 ||
            push!(warnings, "current checker source drifted")
        adapter_file = _model_evaluation_project_file(
            realpath(project_root),
            record.adapter_source_origin,
            "recorded adapter source",
        )
        _model_evaluation_sha256_file(adapter_file.actual) == record.adapter_source_sha256 ||
            push!(warnings, "current adapter source drifted")
    catch err
        push!(warnings, "current registry validation failed: $(sprint(showerror, err))")
    end
    (; kind, ok=isempty(errors), evaluation_id=record.evaluation_id, errors, warnings, record)
end

function list_model_evaluations(
    evidence_root::AbstractString;
    project_root::AbstractString=evidence_root,
    vp_id::Union{AbstractString,Nothing}=nothing,
    contract_id::Union{AbstractString,Nothing}=nothing,
    outcome::Union{Symbol,Nothing}=nothing,
    counterexample_candidates::Bool=false,
)
    outcome === nothing || outcome in _MODEL_EVALUATION_OUTCOMES ||
        throw(ArgumentError("outcome must be pass, reject, or error"))
    parent = _model_evaluation_existing_directory(
        evidence_root,
        "logs",
        "model-evaluations",
    )
    parent === nothing && return NamedTuple[]
    entries = NamedTuple[]
    filtered = vp_id !== nothing || contract_id !== nothing || outcome !== nothing ||
        counterexample_candidates
    for id in sort(readdir(parent))
        startswith(id, ".pending-") && continue
        isdir(joinpath(parent, id)) || continue
        audit = audit_model_evaluation(evidence_root, id; project_root=project_root)
        record = audit.record
        if record === nothing
            filtered || push!(entries, (
                    evaluation_id=id,
                    audit_ok=false,
                    errors=audit.errors,
                    warnings=audit.warnings,
                ))
            continue
        end
        vp_id === nothing || record.vp_id == vp_id || continue
        contract_id === nothing || record.contract_id == contract_id || continue
        outcome === nothing || record.outcome == outcome || continue
        counterexample_candidates && record.claim_relation != :counterexample_candidate && continue
        push!(entries, (
            evaluation_id=id,
            vp_id=record.vp_id,
            contract_id=record.contract_id,
            checker_id=record.checker_id,
            adapter_id=record.adapter_id,
            outcome=record.outcome,
            claim_relation=record.claim_relation,
            model_fingerprint=record.model_fingerprint,
            generated_unix=record.generated_unix,
            audit_ok=audit.ok,
            errors=audit.errors,
            warnings=audit.warnings,
        ))
    end
    entries
end

function audit_model_evaluations(
    evidence_root::AbstractString;
    project_root::AbstractString=evidence_root,
)
    if !isdir(evidence_root)
        return (
            kind=:model_evaluation_audit,
            ok=false,
            checked=0,
            failed=0,
            errors=["evidence root does not exist or is not a directory"],
            duplicate_fingerprints=NamedTuple[],
            entries=NamedTuple[],
        )
    end
    entries = try
        list_model_evaluations(evidence_root; project_root=project_root)
    catch err
        return (
            kind=:model_evaluation_audit,
            ok=false,
            checked=0,
            failed=0,
            errors=["evaluation directory validation failed: $(sprint(showerror, err))"],
            duplicate_fingerprints=NamedTuple[],
            entries=NamedTuple[],
        )
    end
    fingerprints = Dict{String,Vector{String}}()
    for entry in entries
        hasproperty(entry, :model_fingerprint) || continue
        push!(get!(fingerprints, entry.model_fingerprint, String[]), entry.evaluation_id)
    end
    duplicates = [
        (model_fingerprint=fingerprint, evaluation_ids=ids)
        for (fingerprint, ids) in sort!(collect(fingerprints); by=first)
        if length(ids) > 1
    ]
    (
        kind=:model_evaluation_audit,
        ok=all(entry -> entry.audit_ok, entries),
        checked=length(entries),
        failed=count(entry -> !entry.audit_ok, entries),
        errors=String[],
        duplicate_fingerprints=duplicates,
        entries=entries,
    )
end

function write_counterexample_draft_packet(
    evidence_root::AbstractString,
    evaluation_id::AbstractString;
    project_root::AbstractString=evidence_root,
)
    audit = audit_model_evaluation(evidence_root, evaluation_id; project_root=project_root)
    audit.ok || throw(ArgumentError("evaluation must pass audit before draft generation"))
    isempty(audit.warnings) || throw(ArgumentError(
        "current registry/checker drift must be resolved before draft generation",
    ))
    record = audit.record
    record.outcome == :reject ||
        throw(ArgumentError("only reject evaluations can produce a counterexample draft"))
    record.claim_relation == :counterexample_candidate ||
        throw(ArgumentError("evaluation is not marked counterexample_candidate"))
    record.checker_relation == "exact_finite_decision" ||
        throw(ArgumentError("draft generation requires exact_finite_decision"))
    registry = JSON3.read(read(joinpath(evidence_root, record.registry_snapshot), String))
    packet = (
        kind=:counterexample_claim_draft,
        schema_version=1,
        source_evaluation=relpath(model_evaluation_path(evidence_root, evaluation_id), evidence_root),
        source_evaluation_sha256=_model_evaluation_sha256_file(
            model_evaluation_path(evidence_root, evaluation_id),
        ),
        evaluation_id=record.evaluation_id,
        vp_id=record.vp_id,
        contract_id=record.contract_id,
        checker_id=record.checker_id,
        checker_relation=record.checker_relation,
        adapter_id=record.adapter_id,
        adapter_version=record.adapter_version,
        lean_decl=record.lean_decl,
        witness_artifact=record.model_artifact,
        witness_sha256=record.model_artifact_sha256,
        model_fingerprint=record.model_fingerprint,
        failed_predicates=record.failed_predicates,
        semantic_scope=String(registry.scope),
        semantic_assumptions=String[String(item) for item in registry.assumptions],
        semantic_guarantee=String(registry.guarantee),
        target_claim_id=nothing,
        promotion_status=:blocked,
        blocking_requirements=[
            "freeze an exact existential Lean statement with all assumptions",
            "identify or create the target counterexample claim id",
            "prove the statement without sorry or new axioms",
        ],
        automatic_promotion=false,
        claim_status=:draft_not_a_claim,
        phenomenal_claim=:not_certified,
    )
    parent = _model_evaluation_secure_directory(
        realpath(evidence_root),
        "logs",
        "counterexample-candidates",
    )
    destination = joinpath(parent, String(evaluation_id))
    ispath(destination) && throw(ArgumentError("counterexample draft already exists"))
    temporary = mktempdir(parent; prefix=".pending-")
    try
        bytes = Vector{UInt8}(codeunits(String(JSON3.write(packet)) * "\n"))
        write(joinpath(temporary, "packet.json"), bytes)
        write(
            joinpath(temporary, "seal.sha256"),
            "$(_model_evaluation_sha256(bytes))  packet.json\n",
        )
        mv(temporary, destination)
    catch
        ispath(temporary) && rm(temporary; recursive=true)
        rethrow()
    end
    joinpath(destination, "packet.json")
end
