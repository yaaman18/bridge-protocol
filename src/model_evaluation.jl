import JSON3
import SHA
import TOML

const MODEL_EVALUATION_SCHEMA_VERSION = 3
const COUNTEREXAMPLE_DRAFT_SCHEMA_VERSION = 1
const MODEL_EVALUATION_FINGERPRINT_ALGORITHM =
    "sha256:eriec-canonical-model-bytes-v1"
const MODEL_EVALUATION_RAW_FINGERPRINT_ALGORITHM =
    "sha256:eriec-raw-input-bytes-v1"
const _MODEL_EVALUATION_OUTCOMES = Set((:pass, :reject, :error))
const _MODEL_EVALUATION_ERROR_STAGES =
    Set((:input_schema, :adapter, :checker, :postflight, :legacy_unknown))
const _MODEL_EVALUATION_CLAIM_RELATIONS =
    Set((:observation_only, :counterexample_candidate))
const _MODEL_EVALUATION_ID = r"^[A-Za-z0-9][A-Za-z0-9._-]*\z"
const _MODEL_EVALUATION_SHA256 = r"^[0-9a-f]{64}\z"
const _MODEL_EVALUATION_CATALOG_CACHE = Dict{Tuple{String,String},Any}()
const _MODEL_EVALUATION_GIT_BLOB_CACHE =
    Dict{Tuple{String,String,String},Vector{UInt8}}()
const _MODEL_EVALUATION_VERIFIED_CONTRACT_CACHE =
    Set{Tuple{String,String,String,String}}()
const _MODEL_EVALUATION_CATALOG_LOCK = ReentrantLock()
const _MODEL_EVALUATION_CHECKER_LOCK = ReentrantLock()
const _MODEL_EVALUATION_ID_LOCK = ReentrantLock()
const _MODEL_EVALUATION_ID_COUNTER = Ref{UInt64}(0)
const _MODEL_EVALUATION_M4_CHECKER_METHOD = which(
    check_m4_no_terminal_setpoint,
    Tuple{SetPointDiagram},
)
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
    "claim_relation", "claim_status", "error_stage", "error_message",
    "error_diagnostics", "seed",
    "numeric_assumptions", "git_commit", "git_dirty", "julia_version",
    "manifest_sha256", "log_path", "log_sha256", "generated_unix",
    "phenomenal_claim", "execution_layer", "execution_certified",
    "execution_boundary", "execution_note",
])
const _MODEL_EVALUATION_PAYLOAD_KEYS_V2 = setdiff(
    _MODEL_EVALUATION_PAYLOAD_KEYS,
    Set(["error_stage", "error_diagnostics"]),
)
const _MODEL_EVALUATION_REGISTRY_KEYS = Set([
    "kind", "vp_id", "contract_id", "lean_decl", "checker_id",
    "checker_relation", "checker_source", "scope", "assumptions", "guarantee",
    "review_status", "reviewer", "basis_log",
    "catalog_artifact_id", "catalog_version", "ledger_sha256",
    "semantic_manifest_sha256", "certified_artifact_source_sha256",
    "lean_declaration_source_sha256", "registry_git_commit",
    "registry_generation_sha256",
])
const _MODEL_EVALUATION_REGISTRY_KEYS_V2 = setdiff(
    _MODEL_EVALUATION_REGISTRY_KEYS,
    Set([
        "review_status", "reviewer", "basis_log",
        "lean_declaration_source_sha256", "registry_git_commit",
        "registry_generation_sha256",
    ]),
)
const _COUNTEREXAMPLE_DRAFT_KEYS = Set([
    "kind", "schema_version", "source_evaluation", "source_evaluation_sha256",
    "evaluation_id", "vp_id", "contract_id", "checker_id", "checker_relation",
    "adapter_id", "adapter_version", "lean_decl", "witness_artifact",
    "witness_sha256", "model_fingerprint", "failed_predicates",
    "registry_snapshot_sha256", "semantic_scope",
    "semantic_assumptions", "semantic_guarantee", "review_status", "reviewer",
    "basis_log", "target_claim_id", "promotion_status", "blocking_requirements",
    "automatic_promotion", "claim_status", "phenomenal_claim",
])

function _model_evaluation_valid_id(value::AbstractString)
    id = String(value)
    isvalid(id) || throw(ArgumentError("evaluation_id must be valid UTF-8"))
    occursin(_MODEL_EVALUATION_ID, id) ||
        throw(ArgumentError("evaluation_id must match $(_MODEL_EVALUATION_ID.pattern)"))
    id
end

function _model_evaluation_utf8_safe(value::AbstractString)
    text = String(value)
    isvalid(text) && return text
    io = IOBuffer()
    for byte in codeunits(text)
        if byte == 0x09 || byte == 0x0a || byte == 0x0d || 0x20 <= byte <= 0x7e
            write(io, byte)
        else
            print(io, "\\x", lowercase(string(byte; base=16, pad=2)))
        end
    end
    String(take!(io))
end

function _model_evaluation_diagnostic(stage::Symbol, message::AbstractString)
    stage in _MODEL_EVALUATION_ERROR_STAGES ||
        throw(ArgumentError("unsupported model evaluation error stage: $stage"))
    safe = _model_evaluation_utf8_safe(message)
    isempty(safe) && throw(ArgumentError("error diagnostic message must be nonempty"))
    (stage=stage, message=safe)
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
    error_stage::Union{Symbol,Nothing}
    error_message::Union{String,Nothing}
    error_diagnostics::Vector{NamedTuple{(:stage,:message),Tuple{Symbol,String}}}
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
    isvalid(path) || throw(ArgumentError("$field must be valid UTF-8"))
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

function _model_evaluation_publish_create_only(
    temporary::AbstractString,
    destination::AbstractString,
    artifact_name::AbstractString,
)
    parent = dirname(destination)
    lock_path = joinpath(parent, ".pending-lock-$(basename(destination))")
    acquired = false
    try
        try
            mkdir(lock_path)
            acquired = true
        catch err
            (ispath(lock_path) || islink(lock_path)) && throw(ArgumentError(
                "$artifact_name is already being published",
            ))
            rethrow(err)
        end
        (ispath(destination) || islink(destination)) && throw(ArgumentError(
            "$artifact_name already exists; artifacts are create-only",
        ))
        Base.Filesystem.rename(temporary, destination)
    finally
        acquired && ispath(lock_path) && rm(lock_path; recursive=true)
    end
    destination
end

function _model_evaluation_hash(value::AbstractString, field::AbstractString)
    hash = String(value)
    occursin(_MODEL_EVALUATION_SHA256, hash) ||
        throw(ArgumentError("$field must be a lowercase SHA-256 digest"))
    hash
end

function _model_evaluation_json_safe(value, field::AbstractString="numeric_assumptions")
    if value isa AbstractString
        isvalid(value) || throw(ArgumentError("$field must contain valid UTF-8 strings"))
        return true
    elseif value === nothing || value isa Bool || value isa Symbol || value isa Integer
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
    schema_version::Integer=MODEL_EVALUATION_SCHEMA_VERSION,
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
    error_stage::Union{Symbol,Nothing}=nothing,
    error_message::Union{AbstractString,Nothing}=nothing,
    error_diagnostics=NamedTuple[],
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
    normalized_schema_version = Int(schema_version)
    normalized_schema_version in (2, MODEL_EVALUATION_SCHEMA_VERSION) ||
        throw(ArgumentError("unsupported model evaluation schema version"))
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
    message = error_message === nothing ? nothing :
        _model_evaluation_utf8_safe(error_message)
    diagnostics = NamedTuple{(:stage,:message),Tuple{Symbol,String}}[]
    for diagnostic in error_diagnostics
        hasproperty(diagnostic, :stage) && hasproperty(diagnostic, :message) ||
            throw(ArgumentError("error_diagnostics entries require stage and message"))
        push!(diagnostics, _model_evaluation_diagnostic(
            Symbol(diagnostic.stage),
            String(diagnostic.message),
        ))
    end
    normalized_schema_version == MODEL_EVALUATION_SCHEMA_VERSION &&
        any(diagnostic -> diagnostic.stage == :legacy_unknown, diagnostics) &&
        throw(ArgumentError("legacy_unknown is only valid for schema version 2"))
    outcome == :error && (message === nothing || isempty(message)) &&
        throw(ArgumentError("error evaluations require error_message"))
    outcome == :error && error_stage === nothing &&
        throw(ArgumentError("error evaluations require error_stage"))
    outcome == :error && isempty(diagnostics) &&
        throw(ArgumentError("error evaluations require error_diagnostics"))
    outcome == :error && first(diagnostics).stage != error_stage &&
        throw(ArgumentError("error_stage must match the first diagnostic"))
    outcome == :error && first(diagnostics).message != message &&
        throw(ArgumentError("error_message must match the first diagnostic"))
    outcome != :error && message !== nothing &&
        throw(ArgumentError("only error evaluations may have error_message"))
    outcome != :error && error_stage !== nothing &&
        throw(ArgumentError("only error evaluations may have error_stage"))
    outcome != :error && !isempty(diagnostics) &&
        throw(ArgumentError("only error evaluations may have error_diagnostics"))
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
        isvalid(value) || throw(ArgumentError("$(field) must be valid UTF-8"))
    end
    startswith(strings.model_fingerprint, "sha256:") ||
        throw(ArgumentError("model_fingerprint must use a sha256: prefix"))
    _model_evaluation_hash(strings.model_fingerprint[8:end], "model_fingerprint")

    ModelEvaluationRecord(
        normalized_schema_version,
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
        error_stage,
        message,
        diagnostics,
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
    payload = (
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
        error_stage=record.error_stage,
        error_message=record.error_message,
        error_diagnostics=record.error_diagnostics,
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
    if record.schema_version == 2
        names = Tuple(filter(
            name -> !(name in (:error_stage, :error_diagnostics)),
            propertynames(payload),
        ))
        return NamedTuple{names}(Tuple(getproperty(payload, name) for name in names))
    end
    payload
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
    "schema_version" in actual_keys ||
        throw(ArgumentError("missing model evaluation fields: schema_version"))
    payload.schema_version isa Integer && !(payload.schema_version isa Bool) ||
        throw(ArgumentError("schema_version must be an integer"))
    schema_version = Int(payload.schema_version)
    schema_version in (2, MODEL_EVALUATION_SCHEMA_VERSION) ||
        throw(ArgumentError("unsupported model evaluation schema version"))
    expected_keys = schema_version == 2 ?
        _MODEL_EVALUATION_PAYLOAD_KEYS_V2 : _MODEL_EVALUATION_PAYLOAD_KEYS
    actual_keys == expected_keys || begin
        missing = sort!(collect(setdiff(expected_keys, actual_keys)))
        unknown = sort!(collect(setdiff(actual_keys, expected_keys)))
        isempty(missing) ||
            throw(ArgumentError("missing model evaluation fields: $(join(missing, ", "))"))
        throw(ArgumentError("unknown model evaluation fields: $(join(unknown, ", "))"))
    end
    String(payload.kind) == "model_evaluation" ||
        throw(ArgumentError("artifact kind must be model_evaluation"))
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
    diagnostics = NamedTuple[]
    error_stage = nothing
    if schema_version == 2
        if String(payload.outcome) == "error"
            error_stage = :legacy_unknown
            push!(diagnostics, (
                stage=error_stage,
                message=String(payload.error_message),
            ))
        end
    else
        payload.error_diagnostics isa JSON3.Array ||
            throw(ArgumentError("error_diagnostics must be an array"))
        for item in payload.error_diagnostics
            item isa JSON3.Object ||
                throw(ArgumentError("error_diagnostics entries must be objects"))
            Set(String[String(key) for key in keys(item)]) == Set(["stage", "message"]) ||
                throw(ArgumentError("error_diagnostics entries require only stage and message"))
            push!(diagnostics, (
                stage=Symbol(String(item.stage)),
                message=String(item.message),
            ))
        end
        error_stage = payload.error_stage === nothing ? nothing :
            Symbol(String(payload.error_stage))
    end
    ModelEvaluationRecord(
        schema_version=schema_version,
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
        error_stage=error_stage,
        error_message=payload.error_message === nothing ? nothing : String(payload.error_message),
        error_diagnostics=diagnostics,
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

function _model_evaluation_source_set_sha256(
    project_root::AbstractString,
    paths::AbstractVector{<:AbstractString},
)
    isempty(paths) && throw(ArgumentError("Lean declaration module has no source files"))
    entries = [
        (
            path=relpath(realpath(path), realpath(project_root)),
            sha256=_model_evaluation_sha256_file(path),
        )
        for path in sort!(String[String(path) for path in paths])
    ]
    _model_evaluation_sha256(String(JSON3.write(entries)))
end

function _model_evaluation_require_head_bytes(
    project_root::AbstractString,
    git_commit::AbstractString,
    path::AbstractString,
    bytes::AbstractVector{UInt8},
    field::AbstractString,
)
    project = realpath(project_root)
    relative = relpath(realpath(path), project)
    startswith(relative, "..") &&
        throw(ArgumentError("$field must stay inside the project root"))
    key = (project, String(git_commit), relative)
    committed = lock(_MODEL_EVALUATION_CATALOG_LOCK) do
        get!(_MODEL_EVALUATION_GIT_BLOB_CACHE, key) do
            specification = "$(git_commit):$relative"
            read(Cmd(`git show $specification`; dir=project))
        end
    end
    Vector{UInt8}(bytes) == committed || throw(ArgumentError(
        "$field must match the recorded Git commit before evaluation",
    ))
    nothing
end

function _model_evaluation_registry_binding(
    project_root::AbstractString,
    vp_id::AbstractString,
    contract_id::AbstractString,
    checker_id::AbstractString,
)
    registry_git_commit = readchomp(Cmd(`git rev-parse HEAD`; dir=project_root))
    ledger_path = joinpath(project_root, "specs", "ledger.toml")
    ledger_bytes = read(ledger_path)
    _model_evaluation_require_head_bytes(
        project_root,
        registry_git_commit,
        ledger_path,
        ledger_bytes,
        "ledger",
    )
    ledger = TOML.parse(String(copy(ledger_bytes)))
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
    manifest_bytes = read(manifest_path)
    _model_evaluation_require_head_bytes(
        project_root,
        registry_git_commit,
        manifest_path,
        manifest_bytes,
        "semantic manifest",
    )
    manifest = TOML.parse(String(copy(manifest_bytes)))
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
    reviewer = String(get(semantic, "reviewer", ""))
    basis_log = String(get(semantic, "basis_log", ""))
    isempty(reviewer) && throw(ArgumentError("reviewed semantic contract requires reviewer"))
    isempty(basis_log) && throw(ArgumentError("reviewed semantic contract requires basis_log"))

    catalog_source = joinpath(project_root, "formal", "ERIEC", "CertifiedArtifact.lean")
    isfile(catalog_source) || throw(ArgumentError("certificate catalog source is missing"))
    catalog_source_bytes = read(catalog_source)
    _model_evaluation_require_head_bytes(
        project_root,
        registry_git_commit,
        catalog_source,
        catalog_source_bytes,
        "certificate catalog source",
    )
    catalog_source_sha256 = _model_evaluation_sha256(catalog_source_bytes)
    catalog_key = (
        realpath(project_root),
        catalog_source_sha256,
    )
    artifact = lock(_MODEL_EVALUATION_CATALOG_LOCK) do
        get!(_MODEL_EVALUATION_CATALOG_CACHE, catalog_key) do
            lean_certified_artifact(; project_root=project_root)
        end
    end
    _model_evaluation_sha256_file(catalog_source) == catalog_source_sha256 ||
        throw(ArgumentError("certificate catalog source changed while resolving binding"))
    catalog = filter(contract -> contract.id == contract_id, artifact.contracts)
    length(catalog) == 1 || throw(ArgumentError("contract is absent from certificate catalog"))
    certified = only(catalog)
    certified.lean_full_name == String(vp["lean_decl"]) ||
        throw(ArgumentError("certificate catalog Lean declaration does not match VP binding"))
    certified.julia_checker == Symbol(checker_id) ||
        throw(ArgumentError("certificate catalog checker does not match VP binding"))
    declaration_sources = _module_source_paths(project_root, certified.lean_module)
    for source_path in declaration_sources
        source_bytes = read(source_path)
        _model_evaluation_require_head_bytes(
            project_root,
            registry_git_commit,
            source_path,
            source_bytes,
            "Lean declaration source",
        )
    end
    declaration_source_sha256 = _model_evaluation_source_set_sha256(
        project_root,
        declaration_sources,
    )
    registry_generation_sha256 = _model_evaluation_sha256(String(JSON3.write((
        ledger_sha256=_model_evaluation_sha256(ledger_bytes),
        semantic_manifest_sha256=_model_evaluation_sha256(manifest_bytes),
        certified_artifact_source_sha256=catalog_source_sha256,
        lean_declaration_source_sha256=declaration_source_sha256,
        registry_git_commit,
    ))))
    verification_key = (
        realpath(project_root),
        catalog_key[2],
        declaration_source_sha256,
        String(contract_id),
    )
    lock(_MODEL_EVALUATION_CATALOG_LOCK) do
        if !(verification_key in _MODEL_EVALUATION_VERIFIED_CONTRACT_CACHE)
            isempty(_missing_lean_full_names(project_root, [certified])) ||
                throw(ArgumentError("catalog Lean declaration does not resolve"))
            _model_evaluation_source_set_sha256(project_root, declaration_sources) ==
                declaration_source_sha256 || throw(ArgumentError(
                    "Lean declaration source changed while verifying binding",
                ))
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
        review_status=String(semantic["review_status"]),
        reviewer,
        basis_log,
        catalog_artifact_id=artifact.artifact_id,
        catalog_version=artifact.version,
        ledger_sha256=_model_evaluation_sha256(ledger_bytes),
        semantic_manifest_sha256=_model_evaluation_sha256(manifest_bytes),
        certified_artifact_source_sha256=catalog_key[2],
        lean_declaration_source_sha256=declaration_source_sha256,
        registry_git_commit,
        registry_generation_sha256,
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
        review_status=binding.review_status,
        reviewer=binding.reviewer,
        basis_log=binding.basis_log,
        catalog_artifact_id=binding.catalog_artifact_id,
        catalog_version=binding.catalog_version,
        ledger_sha256=binding.ledger_sha256,
        semantic_manifest_sha256=binding.semantic_manifest_sha256,
        certified_artifact_source_sha256=binding.certified_artifact_source_sha256,
        lean_declaration_source_sha256=binding.lean_declaration_source_sha256,
        registry_git_commit=binding.registry_git_commit,
        registry_generation_sha256=binding.registry_generation_sha256,
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
    _model_evaluation_utf8_safe(String(take!(io)))
end

_model_evaluation_showerror(err) =
    _model_evaluation_utf8_safe(sprint(showerror, err))

function _model_evaluation_decode_registered_adapter(
    adapter_id::String,
    bytes::Vector{UInt8},
)
    adapter_id == "m4-setpoint-model-v1" ||
        throw(ArgumentError("unsupported model evaluation adapter: $adapter_id"))
    method = which(
        _decode_model_evaluation_adapter,
        Tuple{AbstractString,AbstractVector{UInt8}},
    )
    method === _M4_MODEL_EVALUATION_DECODE_METHOD ||
        throw(ArgumentError("registered adapter decoder method changed after ERIEC loaded"))
    invoke(
        _decode_model_evaluation_adapter,
        Tuple{AbstractString,AbstractVector{UInt8}},
        adapter_id,
        bytes,
    )
end

function _model_evaluation_registered_adapter_value(
    adapter_id::String,
    decoded,
)
    adapter_id == "m4-setpoint-model-v1" ||
        throw(ArgumentError("unsupported model evaluation adapter: $adapter_id"))
    decoded isa M4SetPointModel ||
        throw(ArgumentError("registered M4 adapter returned the wrong decoded type"))
    method = which(
        _model_evaluation_adapter_value,
        Tuple{AbstractString,M4SetPointModel},
    )
    method === _M4_MODEL_EVALUATION_VALUE_METHOD ||
        throw(ArgumentError("registered adapter value method changed after ERIEC loaded"))
    invoke(
        _model_evaluation_adapter_value,
        Tuple{AbstractString,M4SetPointModel},
        adapter_id,
        decoded,
    )
end


function _model_evaluation_exact_adapter_outcome(adapter_id::String, decoded)
    adapter_id == "m4-setpoint-model-v1" ||
        throw(ArgumentError("unsupported model evaluation adapter: $adapter_id"))
    decoded isa M4SetPointModel ||
        throw(ArgumentError("registered M4 adapter returned the wrong decoded type"))
    edges = Set(decoded.reaches)
    !any(
        candidate -> all(
            source -> (source, candidate) in edges,
            decoded.objects,
        ),
        decoded.objects,
    )
end

const _MODEL_EVALUATION_EXACT_OUTCOME_METHOD = which(
    _model_evaluation_exact_adapter_outcome,
    Tuple{String,Any},
)

function _model_evaluation_registered_exact_outcome(adapter_id::String, decoded)
    which(_model_evaluation_exact_adapter_outcome, Tuple{String,Any}) ===
        _MODEL_EVALUATION_EXACT_OUTCOME_METHOD || throw(ArgumentError(
            "registered adapter exact-decision method changed after ERIEC loaded",
        ))
    invoke(
        _model_evaluation_exact_adapter_outcome,
        Tuple{String,Any},
        adapter_id,
        decoded,
    )
end

function _model_evaluation_registered_checker(checker_id::String, value)
    checker_id == "check_m4_no_terminal_setpoint" ||
        throw(ArgumentError("unsupported registered model checker: $checker_id"))
    value isa SetPointDiagram ||
        throw(ArgumentError("registered M4 checker received the wrong value type"))
    checker = getfield(@__MODULE__, Symbol(checker_id))
    generic_method = which(checker, Tuple{SetPointDiagram})
    selected_method = which(checker, Tuple{typeof(value)})
    generic_method === _MODEL_EVALUATION_M4_CHECKER_METHOD &&
        selected_method === _MODEL_EVALUATION_M4_CHECKER_METHOD ||
        throw(ArgumentError("registered checker method changed after ERIEC loaded"))
    invoke(checker, Tuple{SetPointDiagram}, value)
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
    vp_id::AbstractString,
    contract_id::AbstractString,
    checker_id::AbstractString,
    failed_predicates_on_reject,
    adapter_id::AbstractString,
    claim_relation::Symbol=:observation_only,
    seed::Union{Integer,Nothing}=nothing,
    numeric_assumptions::NamedTuple=NamedTuple(),
)
    project = realpath(project_root)
    output = realpath(mkpath(abspath(output_root)))
    binding = _model_evaluation_registry_binding(project, vp_id, contract_id, checker_id)
    manifest_path = joinpath(project, "Manifest.toml")
    manifest_bytes = isfile(manifest_path) ? read(manifest_path) : UInt8[]
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
    adapter_source = normalized_adapter_id == "m4-setpoint-model-v1" ?
        "src/m4_model_evaluation.jl" :
        throw(ArgumentError("unsupported model evaluation adapter: $normalized_adapter_id"))
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
    claim_relation == :counterexample_candidate &&
        binding.checker_relation != "exact_finite_decision" &&
        throw(ArgumentError(
            "counterexample candidates require a reviewed exact_finite_decision checker",
        ))
    _model_evaluation_json_safe(numeric_assumptions)
    raw_bytes = Vector{UInt8}(raw_model_bytes)

    decoded = nothing
    prepared_value = nothing
    canonical_bytes = raw_bytes
    fingerprint_algorithm = MODEL_EVALUATION_RAW_FINGERPRINT_ALGORITHM
    outcome = :error
    diagnostics = NamedTuple{(:stage,:message),Tuple{Symbol,String}}[]
    function capture_error!(stage::Symbol, err, backtrace)
        push!(diagnostics, _model_evaluation_diagnostic(
            stage,
            _model_evaluation_error_text(err, backtrace),
        ))
        nothing
    end
    capture_path, capture_io = mktemp()
    try
        decoded = _model_evaluation_decode_registered_adapter(
            normalized_adapter_id,
            raw_bytes,
        )
        hasproperty(decoded, :canonical_bytes) ||
            throw(ArgumentError("registered adapter decoder must return canonical_bytes"))
        hasproperty(decoded, :decoded) ||
            throw(ArgumentError("registered adapter decoder must return decoded"))
        canonical_bytes = Vector{UInt8}(decoded.canonical_bytes)
        isempty(canonical_bytes) && throw(ArgumentError("canonical model must be nonempty"))
        fingerprint_algorithm = hasproperty(decoded, :fingerprint_algorithm) ?
            String(decoded.fingerprint_algorithm) : MODEL_EVALUATION_FINGERPRINT_ALGORITHM
    catch err
        capture_error!(:input_schema, err, catch_backtrace())
    end
    if isempty(diagnostics)
        try
            prepared_value = _model_evaluation_registered_adapter_value(
                normalized_adapter_id,
                decoded.decoded,
            )
        catch err
            capture_error!(:adapter, err, catch_backtrace())
        end
    end
    if isempty(diagnostics)
        try
            result = lock(_MODEL_EVALUATION_CHECKER_LOCK) do
                redirect_stdout(capture_io) do
                    redirect_stderr(capture_io) do
                        _model_evaluation_registered_checker(
                            binding.checker_id,
                            prepared_value,
                        )
                    end
                end
            end
            result isa Bool || throw(ArgumentError("model checker must return Bool"))
            expected_result = _model_evaluation_registered_exact_outcome(
                normalized_adapter_id,
                decoded.decoded,
            )
            result == expected_result || throw(ArgumentError(
                "registered checker disagrees with the adapter exact decision",
            ))
            outcome = result ? :pass : :reject
        catch err
            capture_error!(:checker, err, catch_backtrace())
        end
    end
    try
        close(capture_io)
    catch err
        capture_error!(:postflight, err, catch_backtrace())
    end
    try
        _model_evaluation_sha256_file(joinpath(project, binding.checker_source)) ==
            _model_evaluation_sha256(checker_source_bytes) ||
            throw(ArgumentError("checker source changed during execution"))
        _model_evaluation_sha256_file(adapter_file.actual) ==
            _model_evaluation_sha256(adapter_source_bytes) ||
            throw(ArgumentError("adapter source changed during execution"))
        rebound = _model_evaluation_registry_binding(
            project,
            vp_id,
            contract_id,
            checker_id,
        )
        _model_evaluation_registry_payload(rebound) ==
            _model_evaluation_registry_payload(binding) ||
            throw(ArgumentError("registry binding changed during execution"))
        current_manifest_bytes = isfile(manifest_path) ? read(manifest_path) : UInt8[]
        current_manifest_bytes == manifest_bytes ||
            throw(ArgumentError("Julia manifest changed during execution"))
    catch err
        capture_error!(:postflight, err, catch_backtrace())
    end
    isempty(diagnostics) || (outcome = :error)
    error_stage = isempty(diagnostics) ? nothing : first(diagnostics).stage
    error_message = isempty(diagnostics) ? nothing : first(diagnostics).message
    captured = read(capture_path)
    rm(capture_path)
    log_buffer = IOBuffer()
    write(log_buffer, captured)
    for diagnostic in diagnostics
        println(
            log_buffer,
            "\nerror_stage=", diagnostic.stage,
            "\nerror_message=", diagnostic.message,
        )
    end
    println(log_buffer, "outcome=", outcome)
    log_bytes = take!(log_buffer)

    id = _model_evaluation_valid_id(evaluation_id === nothing ?
        _model_evaluation_id(vp_id, canonical_bytes) : String(evaluation_id))
    parent = _model_evaluation_secure_directory(output, "logs", "model-evaluations")
    destination = joinpath(parent, id)
    (ispath(destination) || islink(destination)) && throw(ArgumentError(
        "evaluation_id already exists; model evaluations are create-only",
    ))

    registry_bytes = Vector{UInt8}(codeunits(
        String(JSON3.write(_model_evaluation_registry_payload(binding))) * "\n",
    ))
    git = _model_evaluation_git_state(project)
    manifest_sha = _model_evaluation_sha256(manifest_bytes)
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
        error_stage=error_stage,
        error_message=error_message,
        error_diagnostics=diagnostics,
        seed=seed,
        numeric_assumptions=numeric_assumptions,
        git_commit=binding.registry_git_commit,
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
        _model_evaluation_publish_create_only(
            temporary,
            destination,
            "model evaluation",
        )
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
        islink(candidate) && return nothing
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
    replay_errors = String[]
    record = nothing
    evaluation_sha256 = nothing
    seal_bytes = nothing
    semantic_replay = :not_attempted
    kind = :model_evaluation_audit_entry
    id = String(evaluation_id)
    if !isvalid(id) || !occursin(_MODEL_EVALUATION_ID, id)
        push!(errors, "invalid evaluation id")
        return (; kind, ok=false, evaluation_id=_model_evaluation_utf8_safe(id),
            errors, warnings, replay_errors, semantic_replay, record,
            evaluation_sha256=nothing)
    end
    path = model_evaluation_path(evidence_root, id)
    directory = dirname(path)
    if !isfile(path)
        push!(errors, "evaluation.json is missing")
        return (; kind, ok=false, evaluation_id=id, errors, warnings, replay_errors,
            semantic_replay, record, evaluation_sha256=nothing)
    end
    try
        evidence = realpath(evidence_root)
        actual_directory = realpath(directory)
        startswith(actual_directory, evidence * string(Base.Filesystem.path_separator)) ||
            push!(errors, "evaluation directory escapes the evidence root")
        islink(directory) && push!(errors, "evaluation directory must not be a symlink")
    catch err
        push!(errors, "evaluation directory validation failed: $(_model_evaluation_showerror(err))")
    end
    if islink(path)
        push!(errors, "evaluation.json must not be a symlink")
    else
        try
            realpath(path) == joinpath(realpath(directory), "evaluation.json") ||
                push!(errors, "evaluation.json escapes its evaluation directory")
        catch err
            push!(errors, "evaluation.json validation failed: $(_model_evaluation_showerror(err))")
        end
    end
    if !isempty(errors)
        return (; kind, ok=false, evaluation_id=id, errors, warnings, replay_errors,
            semantic_replay, record, evaluation_sha256=nothing)
    end
    try
        evaluation_bytes = read(path)
        evaluation_sha256 = _model_evaluation_sha256(evaluation_bytes)
        record = parse_model_evaluation_json(String(copy(evaluation_bytes)))
    catch err
        push!(errors, "evaluation parse failed: $(_model_evaluation_showerror(err))")
        return (; kind, ok=false, evaluation_id=id, errors, warnings, replay_errors,
            semantic_replay, record, evaluation_sha256=nothing)
    end
    record.evaluation_id == evaluation_id || push!(errors, "directory id does not match record")

    seal_path = joinpath(directory, "seal.sha256")
    if !isfile(seal_path)
        push!(errors, "seal.sha256 is missing")
    elseif islink(seal_path)
        push!(errors, "seal.sha256 must not be a symlink")
    else
        try
            realpath(seal_path) == joinpath(realpath(directory), "seal.sha256") ||
                throw(ArgumentError("seal.sha256 escapes its evaluation directory"))
            seal_bytes = read(seal_path)
            seal_fields = split(strip(String(copy(seal_bytes))))
            length(seal_fields) == 2 && seal_fields[2] == "evaluation.json" ||
                throw(ArgumentError("invalid seal format"))
            expected = _model_evaluation_hash(seal_fields[1], "evaluation seal")
            expected == evaluation_sha256 || push!(errors, "evaluation seal mismatch")
        catch err
            push!(errors, "evaluation seal validation failed: $(_model_evaluation_showerror(err))")
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
                push!(errors, "$name snapshot read failed: $(_model_evaluation_showerror(err))")
            end
        end
    end
    record.model_fingerprint == "sha256:$(record.model_artifact_sha256)" ||
        push!(errors, "model fingerprint is not bound to canonical model bytes")
    record.checker_version == "sha256:$(record.checker_source_sha256)" ||
        push!(errors, "checker version is not bound to checker source bytes")
    record.adapter_version == "sha256:$(record.adapter_source_sha256)" ||
        push!(errors, "adapter version is not bound to adapter source bytes")
    if haskey(resolved_snapshots, :source_model) &&
            haskey(resolved_snapshots, :model) && haskey(resolved_snapshots, :adapter)
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
                adapter_replay_errors = _audit_model_evaluation_adapter(
                    record,
                    resolved_snapshots[:source_model],
                    resolved_snapshots[:model],
                )
                append!(replay_errors, adapter_replay_errors)
                semantic_replay = isempty(adapter_replay_errors) ? :passed : :failed
            catch err
                semantic_replay = :failed
                push!(replay_errors, "adapter audit failed: $(_model_evaluation_showerror(err))")
            end
        else
            semantic_replay = :skipped
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
            expected_registry_keys = record.schema_version == 2 ?
                _MODEL_EVALUATION_REGISTRY_KEYS_V2 :
                _MODEL_EVALUATION_REGISTRY_KEYS
            Set(registry_keys) == expected_registry_keys ||
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
            if record.schema_version == 2
                push!(warnings, "legacy schema v2 registry lacks explicit review provenance")
            else
                String(registry.review_status) == "reviewed" ||
                    throw(ArgumentError("registry review_status must be reviewed"))
                isempty(String(registry.reviewer)) &&
                    throw(ArgumentError("registry reviewer must be nonempty"))
                isempty(String(registry.basis_log)) &&
                    throw(ArgumentError("registry basis_log must be nonempty"))
                _model_evaluation_relative_path(
                    String(registry.basis_log),
                    "registry basis_log",
                )
            end
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
            record.schema_version == 2 || _model_evaluation_hash(
                String(registry.lean_declaration_source_sha256),
                "registry lean_declaration_source_sha256",
            )
            record.schema_version == 2 || _model_evaluation_hash(
                String(registry.registry_generation_sha256),
                "registry registry_generation_sha256",
            )
            if record.schema_version != 2
                isempty(String(registry.registry_git_commit)) &&
                    throw(ArgumentError("registry_git_commit must be nonempty"))
                String(registry.registry_git_commit) == record.git_commit ||
                    push!(errors, "registry Git commit does not match evaluation")
                expected_generation = _model_evaluation_sha256(String(JSON3.write((
                    ledger_sha256=String(registry.ledger_sha256),
                    semantic_manifest_sha256=String(registry.semantic_manifest_sha256),
                    certified_artifact_source_sha256=String(
                        registry.certified_artifact_source_sha256,
                    ),
                    lean_declaration_source_sha256=String(
                        registry.lean_declaration_source_sha256,
                    ),
                    registry_git_commit=String(registry.registry_git_commit),
                ))))
                String(registry.registry_generation_sha256) == expected_generation ||
                    push!(errors, "registry generation digest mismatch")
            end
        catch err
            push!(errors, "registry snapshot parse failed: $(_model_evaluation_showerror(err))")
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
        manifest_path = joinpath(realpath(project_root), "Manifest.toml")
        current_manifest_sha = isfile(manifest_path) ?
            _model_evaluation_sha256_file(manifest_path) :
            _model_evaluation_sha256(UInt8[])
        current_manifest_sha == record.manifest_sha256 ||
            push!(warnings, "current Julia manifest drifted")
    catch err
        push!(warnings, "current registry validation failed: $(_model_evaluation_showerror(err))")
    end
    try
        _model_evaluation_sha256_file(path) == evaluation_sha256 ||
            push!(errors, "evaluation.json changed during audit")
        seal_bytes === nothing || read(seal_path) == seal_bytes ||
            push!(errors, "seal.sha256 changed during audit")
    catch err
        push!(errors, "evaluation metadata postflight failed: $(_model_evaluation_showerror(err))")
    end
    (; kind, ok=isempty(errors), evaluation_id=record.evaluation_id, errors, warnings,
        replay_errors, semantic_replay, record,
        evaluation_sha256)
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
    for raw_id in sort(readdir(parent))
        id = String(raw_id)
        entry_path = joinpath(parent, id)
        if !isvalid(id)
            push!(entries, (
                entry_kind=:foreign,
                evaluation_id=_model_evaluation_utf8_safe(id),
                filter_match=nothing,
                audit_ok=false,
                semantic_replay=:not_attempted,
                replay_errors=String[],
                errors=["foreign entry name is not valid UTF-8"],
                warnings=String[],
            ))
            continue
        end
        if startswith(id, ".pending-")
            push!(entries, (
                entry_kind=:pending,
                evaluation_id=id,
                filter_match=nothing,
                audit_ok=false,
                semantic_replay=:not_attempted,
                replay_errors=String[],
                errors=["incomplete pending evaluation artifact is present"],
                warnings=String[],
            ))
            continue
        end
        if !isdir(entry_path)
            push!(entries, (
                entry_kind=:foreign,
                evaluation_id=id,
                filter_match=nothing,
                audit_ok=false,
                semantic_replay=:not_attempted,
                replay_errors=String[],
                errors=["foreign non-directory entry is present in the evaluation store"],
                warnings=String[],
            ))
            continue
        end
        audit = audit_model_evaluation(evidence_root, id; project_root=project_root)
        record = audit.record
        if record === nothing
            push!(entries, (
                entry_kind=:invalid,
                evaluation_id=id,
                filter_match=nothing,
                audit_ok=false,
                semantic_replay=audit.semantic_replay,
                replay_errors=audit.replay_errors,
                errors=audit.errors,
                warnings=audit.warnings,
            ))
            continue
        end
        matches = (vp_id === nothing || record.vp_id == vp_id) &&
            (contract_id === nothing || record.contract_id == contract_id) &&
            (outcome === nothing || record.outcome == outcome) &&
            (!counterexample_candidates ||
                record.claim_relation == :counterexample_candidate)
        audit.ok && !matches && continue
        push!(entries, (
            entry_kind=:evaluation,
            evaluation_id=id,
            filter_match=matches,
            vp_id=record.vp_id,
            contract_id=record.contract_id,
            checker_id=record.checker_id,
            adapter_id=record.adapter_id,
            outcome=record.outcome,
            claim_relation=record.claim_relation,
            model_fingerprint=record.model_fingerprint,
            generated_unix=record.generated_unix,
            audit_ok=audit.ok,
            semantic_replay=audit.semantic_replay,
            replay_errors=audit.replay_errors,
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
            semantic_replay_complete=false,
            semantic_replay_ok=false,
            semantic_replay_counts=(passed=0, failed=0, skipped=0, not_attempted=0),
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
            errors=["evaluation directory validation failed: $(_model_evaluation_showerror(err))"],
            duplicate_fingerprints=NamedTuple[],
            semantic_replay_complete=false,
            semantic_replay_ok=false,
            semantic_replay_counts=(passed=0, failed=0, skipped=0, not_attempted=0),
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
    replay_counts = (
        passed=count(entry -> entry.semantic_replay == :passed, entries),
        failed=count(entry -> entry.semantic_replay == :failed, entries),
        skipped=count(entry -> entry.semantic_replay == :skipped, entries),
        not_attempted=count(entry -> entry.semantic_replay == :not_attempted, entries),
    )
    (
        kind=:model_evaluation_audit,
        ok=all(entry -> entry.audit_ok, entries),
        checked=length(entries),
        failed=count(entry -> !entry.audit_ok, entries),
        errors=String[],
        duplicate_fingerprints=duplicates,
        semantic_replay_complete=replay_counts.skipped == 0 &&
            replay_counts.not_attempted == 0,
        semantic_replay_ok=replay_counts.failed == 0 && replay_counts.skipped == 0 &&
            replay_counts.not_attempted == 0,
        semantic_replay_counts=replay_counts,
        entries=entries,
    )
end

counterexample_draft_path(root::AbstractString, evaluation_id::AbstractString) = joinpath(
    root,
    "logs",
    "counterexample-candidates",
    _model_evaluation_valid_id(evaluation_id),
    "packet.json",
)

function _model_evaluation_json_string(payload, name::Symbol)
    value = getproperty(payload, name)
    value isa AbstractString || throw(ArgumentError("$name must be a string"))
    text = String(value)
    isvalid(text) || throw(ArgumentError("$name must be valid UTF-8"))
    text
end

function _model_evaluation_json_string_array(payload, name::Symbol; nonempty::Bool=false)
    value = getproperty(payload, name)
    value isa JSON3.Array || throw(ArgumentError("$name must be an array"))
    all(item -> item isa AbstractString && isvalid(item), value) ||
        throw(ArgumentError("$name must contain valid UTF-8 strings"))
    result = String[String(item) for item in value]
    nonempty && isempty(result) && throw(ArgumentError("$name must be nonempty"))
    any(isempty, result) && throw(ArgumentError("$name must not contain empty strings"))
    result
end

function parse_counterexample_draft_json(text::AbstractString)
    payload = JSON3.read(text)
    payload isa JSON3.Object ||
        throw(ArgumentError("counterexample draft must be a JSON object"))
    raw_keys = String[String(key) for key in keys(payload)]
    length(raw_keys) == length(unique(raw_keys)) ||
        throw(ArgumentError("duplicate counterexample draft fields are forbidden"))
    Set(raw_keys) == _COUNTEREXAMPLE_DRAFT_KEYS || begin
        missing = sort!(collect(setdiff(_COUNTEREXAMPLE_DRAFT_KEYS, Set(raw_keys))))
        unknown = sort!(collect(setdiff(Set(raw_keys), _COUNTEREXAMPLE_DRAFT_KEYS)))
        isempty(missing) || throw(ArgumentError(
            "missing counterexample draft fields: $(join(missing, ", "))",
        ))
        throw(ArgumentError(
            "unknown counterexample draft fields: $(join(unknown, ", "))",
        ))
    end
    _model_evaluation_json_string(payload, :kind) == "counterexample_claim_draft" ||
        throw(ArgumentError("draft kind must be counterexample_claim_draft"))
    payload.schema_version isa Integer && !(payload.schema_version isa Bool) ||
        throw(ArgumentError("draft schema_version must be an integer"))
    Int(payload.schema_version) == COUNTEREXAMPLE_DRAFT_SCHEMA_VERSION ||
        throw(ArgumentError("unsupported counterexample draft schema version"))
    evaluation_id = _model_evaluation_valid_id(
        _model_evaluation_json_string(payload, :evaluation_id),
    )
    source_evaluation = _model_evaluation_relative_path(
        _model_evaluation_json_string(payload, :source_evaluation),
        "source_evaluation",
    )
    witness_artifact = _model_evaluation_relative_path(
        _model_evaluation_json_string(payload, :witness_artifact),
        "witness_artifact",
    )
    basis_log = _model_evaluation_relative_path(
        _model_evaluation_json_string(payload, :basis_log),
        "basis_log",
    )
    strings = (
        vp_id=_model_evaluation_json_string(payload, :vp_id),
        contract_id=_model_evaluation_json_string(payload, :contract_id),
        checker_id=_model_evaluation_json_string(payload, :checker_id),
        checker_relation=_model_evaluation_json_string(payload, :checker_relation),
        adapter_id=_model_evaluation_json_string(payload, :adapter_id),
        adapter_version=_model_evaluation_json_string(payload, :adapter_version),
        lean_decl=_model_evaluation_json_string(payload, :lean_decl),
        model_fingerprint=_model_evaluation_json_string(payload, :model_fingerprint),
        semantic_scope=_model_evaluation_json_string(payload, :semantic_scope),
        semantic_guarantee=_model_evaluation_json_string(payload, :semantic_guarantee),
        review_status=_model_evaluation_json_string(payload, :review_status),
        reviewer=_model_evaluation_json_string(payload, :reviewer),
    )
    for (field, value) in pairs(strings)
        isempty(value) && throw(ArgumentError("draft $field must be nonempty"))
    end
    strings.checker_relation == "exact_finite_decision" ||
        throw(ArgumentError("draft checker_relation must be exact_finite_decision"))
    strings.review_status == "reviewed" ||
        throw(ArgumentError("draft review_status must be reviewed"))
    startswith(strings.model_fingerprint, "sha256:") ||
        throw(ArgumentError("draft model_fingerprint must use sha256"))
    _model_evaluation_hash(strings.model_fingerprint[8:end], "draft model_fingerprint")
    failed_predicates = _model_evaluation_json_string_array(
        payload,
        :failed_predicates;
        nonempty=true,
    )
    semantic_assumptions = _model_evaluation_json_string_array(
        payload,
        :semantic_assumptions,
    )
    blocking_requirements = _model_evaluation_json_string_array(
        payload,
        :blocking_requirements;
        nonempty=true,
    )
    payload.target_claim_id === nothing ||
        throw(ArgumentError("draft target_claim_id must remain null"))
    _model_evaluation_json_string(payload, :promotion_status) == "blocked" ||
        throw(ArgumentError("draft promotion_status must be blocked"))
    payload.automatic_promotion === false ||
        throw(ArgumentError("draft automatic_promotion must be false"))
    _model_evaluation_json_string(payload, :claim_status) == "draft_not_a_claim" ||
        throw(ArgumentError("draft claim_status must be draft_not_a_claim"))
    _model_evaluation_json_string(payload, :phenomenal_claim) == "not_certified" ||
        throw(ArgumentError("draft phenomenal_claim must remain not_certified"))
    (
        kind=:counterexample_claim_draft,
        schema_version=COUNTEREXAMPLE_DRAFT_SCHEMA_VERSION,
        source_evaluation,
        source_evaluation_sha256=_model_evaluation_hash(
            _model_evaluation_json_string(payload, :source_evaluation_sha256),
            "draft source_evaluation_sha256",
        ),
        evaluation_id,
        vp_id=strings.vp_id,
        contract_id=strings.contract_id,
        checker_id=strings.checker_id,
        checker_relation=strings.checker_relation,
        adapter_id=strings.adapter_id,
        adapter_version=strings.adapter_version,
        lean_decl=strings.lean_decl,
        witness_artifact,
        witness_sha256=_model_evaluation_hash(
            _model_evaluation_json_string(payload, :witness_sha256),
            "draft witness_sha256",
        ),
        model_fingerprint=strings.model_fingerprint,
        failed_predicates,
        registry_snapshot_sha256=_model_evaluation_hash(
            _model_evaluation_json_string(payload, :registry_snapshot_sha256),
            "draft registry_snapshot_sha256",
        ),
        semantic_scope=strings.semantic_scope,
        semantic_assumptions,
        semantic_guarantee=strings.semantic_guarantee,
        review_status=strings.review_status,
        reviewer=strings.reviewer,
        basis_log,
        target_claim_id=nothing,
        promotion_status=:blocked,
        blocking_requirements,
        automatic_promotion=false,
        claim_status=:draft_not_a_claim,
        phenomenal_claim=:not_certified,
    )
end

read_counterexample_draft(path::AbstractString) =
    parse_counterexample_draft_json(read(path, String))

function write_counterexample_draft_packet(
    evidence_root::AbstractString,
    evaluation_id::AbstractString;
    project_root::AbstractString=evidence_root,
)
    audit = audit_model_evaluation(evidence_root, evaluation_id; project_root=project_root)
    audit.ok || throw(ArgumentError("evaluation must pass audit before draft generation"))
    audit.semantic_replay == :passed || throw(ArgumentError(
        "evaluation semantic replay must pass before draft generation",
    ))
    isempty(audit.warnings) || throw(ArgumentError(
        "current registry/checker drift must be resolved before draft generation",
    ))
    record = audit.record
    record.schema_version == MODEL_EVALUATION_SCHEMA_VERSION ||
        throw(ArgumentError("draft generation requires the current evaluation schema"))
    record.outcome == :reject ||
        throw(ArgumentError("only reject evaluations can produce a counterexample draft"))
    record.claim_relation == :counterexample_candidate ||
        throw(ArgumentError("evaluation is not marked counterexample_candidate"))
    record.checker_relation == "exact_finite_decision" ||
        throw(ArgumentError("draft generation requires exact_finite_decision"))
    canonical_evidence = realpath(evidence_root)
    evaluation_path = model_evaluation_path(canonical_evidence, evaluation_id)
    evaluation_bytes = read(evaluation_path)
    evaluation_sha256 = _model_evaluation_sha256(evaluation_bytes)
    evaluation_sha256 == audit.evaluation_sha256 ||
        throw(ArgumentError("evaluation changed after initial draft audit"))
    captured_record = parse_model_evaluation_json(String(copy(evaluation_bytes)))
    model_evaluation_payload(captured_record) == model_evaluation_payload(record) ||
        throw(ArgumentError("evaluation record changed after initial draft audit"))
    registry_path = _model_evaluation_safe_snapshot(
        canonical_evidence,
        dirname(evaluation_path),
        record.registry_snapshot,
    )
    registry_path === nothing && throw(ArgumentError("registry snapshot is unavailable"))
    registry_bytes = read(registry_path)
    _model_evaluation_sha256(registry_bytes) == record.registry_snapshot_sha256 ||
        throw(ArgumentError("registry snapshot changed after audit"))
    registry = JSON3.read(String(copy(registry_bytes)))
    packet = (
        kind=:counterexample_claim_draft,
        schema_version=1,
        source_evaluation=relpath(evaluation_path, canonical_evidence),
        source_evaluation_sha256=evaluation_sha256,
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
        registry_snapshot_sha256=record.registry_snapshot_sha256,
        semantic_scope=String(registry.scope),
        semantic_assumptions=String[String(item) for item in registry.assumptions],
        semantic_guarantee=String(registry.guarantee),
        review_status=String(registry.review_status),
        reviewer=String(registry.reviewer),
        basis_log=String(registry.basis_log),
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
        canonical_evidence,
        "logs",
        "counterexample-candidates",
    )
    destination = joinpath(parent, String(evaluation_id))
    (ispath(destination) || islink(destination)) &&
        throw(ArgumentError("counterexample draft already exists"))
    temporary = mktempdir(parent; prefix=".pending-")
    try
        bytes = Vector{UInt8}(codeunits(String(JSON3.write(packet)) * "\n"))
        parse_counterexample_draft_json(String(copy(bytes)))
        write(joinpath(temporary, "packet.json"), bytes)
        write(
            joinpath(temporary, "seal.sha256"),
            "$(_model_evaluation_sha256(bytes))  packet.json\n",
        )
        final_audit = audit_model_evaluation(
            canonical_evidence,
            evaluation_id;
            project_root=project_root,
        )
        final_audit.ok && final_audit.semantic_replay == :passed &&
            isempty(final_audit.warnings) || throw(ArgumentError(
                "evaluation changed or drifted during draft generation",
            ))
        final_audit.evaluation_sha256 == audit.evaluation_sha256 ||
            throw(ArgumentError("evaluation digest changed during draft generation"))
        model_evaluation_payload(final_audit.record) == model_evaluation_payload(record) ||
            throw(ArgumentError("evaluation record changed during draft generation"))
        read(evaluation_path) == evaluation_bytes ||
            throw(ArgumentError("evaluation changed during draft generation"))
        read(registry_path) == registry_bytes ||
            throw(ArgumentError("registry snapshot changed during draft generation"))
        _model_evaluation_publish_create_only(
            temporary,
            destination,
            "counterexample draft",
        )
    catch
        ispath(temporary) && rm(temporary; recursive=true)
        rethrow()
    end
    joinpath(destination, "packet.json")
end

function audit_counterexample_draft(
    evidence_root::AbstractString,
    evaluation_id::AbstractString;
    project_root::AbstractString=evidence_root,
)
    kind = :counterexample_draft_audit_entry
    errors = String[]
    warnings = String[]
    replay_errors = String[]
    packet = nothing
    packet_sha256 = nothing
    seal_bytes = nothing
    semantic_replay = :not_attempted
    id = String(evaluation_id)
    if !isvalid(id) || !occursin(_MODEL_EVALUATION_ID, id)
        push!(errors, "invalid evaluation id")
        return (; kind, ok=false, evaluation_id=_model_evaluation_utf8_safe(id),
            errors, warnings, replay_errors, semantic_replay, packet,
            packet_sha256=nothing)
    end
    path = counterexample_draft_path(evidence_root, id)
    directory = dirname(path)
    if !isfile(path)
        push!(errors, "packet.json is missing")
        return (; kind, ok=false, evaluation_id=id, errors, warnings, replay_errors,
            semantic_replay, packet, packet_sha256=nothing)
    end
    try
        evidence = realpath(evidence_root)
        actual_directory = realpath(directory)
        startswith(actual_directory, evidence * string(Base.Filesystem.path_separator)) ||
            push!(errors, "draft directory escapes the evidence root")
        islink(directory) && push!(errors, "draft directory must not be a symlink")
        islink(path) && push!(errors, "packet.json must not be a symlink")
        realpath(path) == joinpath(actual_directory, "packet.json") ||
            push!(errors, "packet.json escapes its draft directory")
    catch err
        push!(errors, "draft directory validation failed: $(_model_evaluation_showerror(err))")
    end
    isempty(errors) ||
        return (; kind, ok=false, evaluation_id=id, errors, warnings, replay_errors,
            semantic_replay, packet, packet_sha256=nothing)
    try
        packet_bytes = read(path)
        packet_sha256 = _model_evaluation_sha256(packet_bytes)
        packet = parse_counterexample_draft_json(String(copy(packet_bytes)))
    catch err
        push!(errors, "draft parse failed: $(_model_evaluation_showerror(err))")
        return (; kind, ok=false, evaluation_id=id, errors, warnings, replay_errors,
            semantic_replay, packet, packet_sha256=nothing)
    end
    packet.evaluation_id == id || push!(errors, "draft directory id does not match packet")
    seal_path = joinpath(directory, "seal.sha256")
    if !isfile(seal_path)
        push!(errors, "seal.sha256 is missing")
    elseif islink(seal_path)
        push!(errors, "seal.sha256 must not be a symlink")
    else
        try
            realpath(seal_path) == joinpath(realpath(directory), "seal.sha256") ||
                throw(ArgumentError("seal.sha256 escapes its draft directory"))
            seal_bytes = read(seal_path)
            seal_fields = split(strip(String(copy(seal_bytes))))
            length(seal_fields) == 2 && seal_fields[2] == "packet.json" ||
                throw(ArgumentError("invalid seal format"))
            expected = _model_evaluation_hash(seal_fields[1], "draft seal")
            expected == packet_sha256 ||
                push!(errors, "draft seal mismatch")
        catch err
            push!(errors, "draft seal validation failed: $(_model_evaluation_showerror(err))")
        end
    end

    expected_source = normpath(joinpath(
        "logs",
        "model-evaluations",
        id,
        "evaluation.json",
    ))
    packet.source_evaluation == expected_source ||
        push!(errors, "draft source_evaluation is not the canonical evaluation path")
    evaluation_audit = audit_model_evaluation(
        evidence_root,
        id;
        project_root=project_root,
    )
    semantic_replay = evaluation_audit.semantic_replay
    append!(
        replay_errors,
        ["source evaluation: $message" for message in evaluation_audit.replay_errors],
    )
    evaluation_audit.ok || append!(
        errors,
        ["source evaluation: $message" for message in evaluation_audit.errors],
    )
    append!(
        warnings,
        ["source evaluation: $message" for message in evaluation_audit.warnings],
    )
    record = evaluation_audit.record
    if record !== nothing
        evaluation_path = model_evaluation_path(evidence_root, id)
        try
            evaluation_audit.evaluation_sha256 == packet.source_evaluation_sha256 ||
                push!(errors, "source evaluation hash mismatch")
        catch err
            push!(errors, "source evaluation read failed: $(_model_evaluation_showerror(err))")
        end
        record.outcome == :reject || push!(errors, "source evaluation is not reject")
        record.claim_relation == :counterexample_candidate ||
            push!(errors, "source evaluation is not a counterexample candidate")
        record.checker_relation == "exact_finite_decision" ||
            push!(errors, "source evaluation checker is not exact_finite_decision")
        comparisons = (
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
            registry_snapshot_sha256=record.registry_snapshot_sha256,
        )
        for (field, expected) in pairs(comparisons)
            getproperty(packet, field) == expected ||
                push!(errors, "draft $field does not match source evaluation")
        end
        registry_path = _model_evaluation_safe_snapshot(
            evidence_root,
            dirname(evaluation_path),
            record.registry_snapshot,
        )
        if registry_path === nothing
            push!(errors, "source registry snapshot is unavailable")
        else
            try
                registry = JSON3.read(read(registry_path, String))
                registry_comparisons = (
                    semantic_scope=String(registry.scope),
                    semantic_assumptions=String[
                        String(item) for item in registry.assumptions
                    ],
                    semantic_guarantee=String(registry.guarantee),
                    review_status=String(registry.review_status),
                    reviewer=String(registry.reviewer),
                    basis_log=String(registry.basis_log),
                )
                for (field, expected) in pairs(registry_comparisons)
                    getproperty(packet, field) == expected ||
                        push!(errors, "draft $field does not match registry snapshot")
                end
            catch err
                push!(errors, "draft registry comparison failed: $(_model_evaluation_showerror(err))")
            end
        end
    end
    try
        _model_evaluation_sha256_file(path) == packet_sha256 ||
            push!(errors, "packet.json changed during audit")
        seal_bytes === nothing || read(seal_path) == seal_bytes ||
            push!(errors, "draft seal changed during audit")
    catch err
        push!(errors, "draft metadata postflight failed: $(_model_evaluation_showerror(err))")
    end
    (; kind, ok=isempty(errors), evaluation_id=id, errors, warnings, replay_errors,
        semantic_replay, packet, packet_sha256)
end

function list_counterexample_drafts(
    evidence_root::AbstractString;
    project_root::AbstractString=evidence_root,
)
    parent = _model_evaluation_existing_directory(
        evidence_root,
        "logs",
        "counterexample-candidates",
    )
    parent === nothing && return NamedTuple[]
    entries = NamedTuple[]
    for raw_id in sort(readdir(parent))
        id = String(raw_id)
        entry_path = joinpath(parent, id)
        if !isvalid(id)
            push!(entries, (
                entry_kind=:foreign,
                evaluation_id=_model_evaluation_utf8_safe(id),
                audit_ok=false,
                semantic_replay=:not_attempted,
                replay_errors=String[],
                errors=["foreign entry name is not valid UTF-8"],
                warnings=String[],
            ))
            continue
        end
        if startswith(id, ".pending-")
            push!(entries, (
                entry_kind=:pending,
                evaluation_id=id,
                audit_ok=false,
                semantic_replay=:not_attempted,
                replay_errors=String[],
                errors=["incomplete pending counterexample draft is present"],
                warnings=String[],
            ))
            continue
        elseif !isdir(entry_path)
            push!(entries, (
                entry_kind=:foreign,
                evaluation_id=id,
                audit_ok=false,
                semantic_replay=:not_attempted,
                replay_errors=String[],
                errors=["foreign non-directory entry is present in the draft store"],
                warnings=String[],
            ))
            continue
        end
        audit = audit_counterexample_draft(
            evidence_root,
            id;
            project_root=project_root,
        )
        push!(entries, (
            entry_kind=audit.packet === nothing ? :invalid : :draft,
            evaluation_id=id,
            audit_ok=audit.ok,
            semantic_replay=audit.semantic_replay,
            replay_errors=audit.replay_errors,
            errors=audit.errors,
            warnings=audit.warnings,
        ))
    end
    entries
end

function audit_counterexample_drafts(
    evidence_root::AbstractString;
    project_root::AbstractString=evidence_root,
)
    if !isdir(evidence_root)
        return (
            kind=:counterexample_draft_audit,
            ok=false,
            checked=0,
            failed=0,
            errors=["evidence root does not exist or is not a directory"],
            semantic_replay_complete=false,
            semantic_replay_ok=false,
            entries=NamedTuple[],
        )
    end
    entries = try
        list_counterexample_drafts(evidence_root; project_root=project_root)
    catch err
        return (
            kind=:counterexample_draft_audit,
            ok=false,
            checked=0,
            failed=0,
            errors=["draft directory validation failed: $(_model_evaluation_showerror(err))"],
            semantic_replay_complete=false,
            semantic_replay_ok=false,
            entries=NamedTuple[],
        )
    end
    semantic_replay_complete = all(
        entry -> entry.semantic_replay in (:passed, :failed),
        entries,
    )
    (
        kind=:counterexample_draft_audit,
        ok=all(entry -> entry.audit_ok, entries),
        checked=length(entries),
        failed=count(entry -> !entry.audit_ok, entries),
        errors=String[],
        semantic_replay_complete,
        semantic_replay_ok=semantic_replay_complete &&
            all(entry -> entry.semantic_replay == :passed, entries),
        entries,
    )
end
