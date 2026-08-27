const M4_SETPOINT_MODEL_SCHEMA_VERSION = 1
const M4_SETPOINT_FINGERPRINT_ALGORITHM =
    "sha256:eriec-set-point-diagram-canonical-json-v1"
const _M4_MODEL_KEYS = Set([
    "kind",
    "schema_version",
    "contract_id",
    "carrier_complete",
    "relation_encoding",
    "objects",
    "reaches",
    "claim_status",
    "phenomenal_claim",
])
const _M4_OBJECT_ID = r"^[A-Za-z0-9][A-Za-z0-9._-]*\z"

"""Finite input for the no-terminal-setpoint component of M4 (the M4b boundary)."""
struct M4SetPointModel
    objects::Tuple{Vararg{String}}
    reaches::Tuple{Vararg{Tuple{String,String}}}

    function M4SetPointModel(objects, reaches)
        normalized_objects = String[String(object) for object in objects]
        isempty(normalized_objects) &&
            throw(ArgumentError("objects must contain at least one object"))
        for object in normalized_objects
            isascii(object) && occursin(_M4_OBJECT_ID, object) || throw(ArgumentError(
                "object ids must be ASCII and match $(_M4_OBJECT_ID.pattern)",
            ))
        end
        length(unique(normalized_objects)) == length(normalized_objects) ||
            throw(ArgumentError("object ids must be unique"))
        object_set = Set(normalized_objects)
        normalized_edges = Tuple{String,String}[]
        for edge in reaches
            length(edge) == 2 || throw(ArgumentError("each reachability edge needs two ids"))
            source, target = String(edge[1]), String(edge[2])
            source in object_set ||
                throw(ArgumentError("edge source is absent from the complete carrier: $source"))
            target in object_set ||
                throw(ArgumentError("edge target is absent from the complete carrier: $target"))
            push!(normalized_edges, (source, target))
        end
        length(unique(normalized_edges)) == length(normalized_edges) ||
            throw(ArgumentError("reachability edges must be unique"))
        new(Tuple(sort(normalized_objects)), Tuple(sort(normalized_edges)))
    end
end

function m4_setpoint_model_payload(model::M4SetPointModel)
    (
        kind=:set_point_diagram_model,
        schema_version=M4_SETPOINT_MODEL_SCHEMA_VERSION,
        contract_id="body.no_terminal_setpoint",
        carrier_complete=true,
        relation_encoding=:closed_world_edge_list,
        objects=model.objects,
        reaches=[[source, target] for (source, target) in model.reaches],
        claim_status=:not_a_claim,
        phenomenal_claim=:not_certified,
    )
end

m4_setpoint_model_json(model::M4SetPointModel) =
    String(JSON3.write(m4_setpoint_model_payload(model)))

function _m4_require_string(payload, name::Symbol)
    value = getproperty(payload, name)
    value isa AbstractString || throw(ArgumentError("$name must be a string"))
    String(value)
end

function parse_m4_setpoint_model_json(text::AbstractString)
    payload = try
        JSON3.read(text)
    catch err
        throw(ArgumentError(
            "invalid JSON: $(_model_evaluation_utf8_safe(sprint(showerror, err)))",
        ))
    end
    payload isa JSON3.Object || throw(ArgumentError("M4 model must be a JSON object"))
    raw_keys = String[String(key) for key in keys(payload)]
    length(raw_keys) == length(unique(raw_keys)) ||
        throw(ArgumentError("duplicate M4 model fields are forbidden"))
    actual_keys = Set(raw_keys)
    missing = sort!(collect(setdiff(_M4_MODEL_KEYS, actual_keys)))
    unknown = sort!(collect(setdiff(actual_keys, _M4_MODEL_KEYS)))
    isempty(missing) || throw(ArgumentError("missing M4 model fields: $(join(missing, ", "))"))
    isempty(unknown) || throw(ArgumentError("unknown M4 model fields: $(join(unknown, ", "))"))

    _m4_require_string(payload, :kind) == "set_point_diagram_model" ||
        throw(ArgumentError("kind must be set_point_diagram_model"))
    payload.schema_version isa Integer && !(payload.schema_version isa Bool) ||
        throw(ArgumentError("schema_version must be an integer"))
    Int(payload.schema_version) == M4_SETPOINT_MODEL_SCHEMA_VERSION ||
        throw(ArgumentError("unsupported M4 model schema version"))
    _m4_require_string(payload, :contract_id) == "body.no_terminal_setpoint" ||
        throw(ArgumentError("contract_id must be body.no_terminal_setpoint"))
    payload.carrier_complete === true ||
        throw(ArgumentError("carrier_complete must be true"))
    _m4_require_string(payload, :relation_encoding) == "closed_world_edge_list" ||
        throw(ArgumentError("relation_encoding must be closed_world_edge_list"))
    _m4_require_string(payload, :claim_status) == "not_a_claim" ||
        throw(ArgumentError("claim_status must be not_a_claim"))
    _m4_require_string(payload, :phenomenal_claim) == "not_certified" ||
        throw(ArgumentError("phenomenal_claim must remain not_certified"))

    payload.objects isa JSON3.Array || throw(ArgumentError("objects must be an array"))
    objects = String[]
    for item in payload.objects
        item isa AbstractString || throw(ArgumentError("object ids must be strings"))
        push!(objects, String(item))
    end
    payload.reaches isa JSON3.Array || throw(ArgumentError("reaches must be an array"))
    reaches = Tuple{String,String}[]
    for edge in payload.reaches
        edge isa JSON3.Array || throw(ArgumentError("each reachability edge must be an array"))
        length(edge) == 2 || throw(ArgumentError("each reachability edge needs two ids"))
        all(item -> item isa AbstractString, edge) ||
            throw(ArgumentError("reachability edge ids must be strings"))
        push!(reaches, (String(edge[1]), String(edge[2])))
    end
    M4SetPointModel(objects, reaches)
end

function _model_evaluation_adapter_source(adapter_id::AbstractString)
    adapter_id == "m4-setpoint-model-v1" ||
        throw(ArgumentError("unsupported model evaluation adapter: $adapter_id"))
    "src/m4_model_evaluation.jl"
end

function _decode_model_evaluation_adapter(
    adapter_id::AbstractString,
    bytes::AbstractVector{UInt8},
)
    _model_evaluation_adapter_source(adapter_id)
    model = parse_m4_setpoint_model_json(String(copy(bytes)))
    (
        decoded=model,
        canonical_bytes=Vector{UInt8}(codeunits(m4_setpoint_model_json(model))),
        fingerprint_algorithm=M4_SETPOINT_FINGERPRINT_ALGORITHM,
    )
end

function _model_evaluation_adapter_value(
    adapter_id::AbstractString,
    model::M4SetPointModel,
)
    _model_evaluation_adapter_source(adapter_id)
    m4_setpoint_diagram(model)
end

const _M4_MODEL_EVALUATION_DECODE_METHOD = which(
    _decode_model_evaluation_adapter,
    Tuple{AbstractString,AbstractVector{UInt8}},
)
const _M4_MODEL_EVALUATION_VALUE_METHOD = which(
    _model_evaluation_adapter_value,
    Tuple{AbstractString,M4SetPointModel},
)

m4_setpoint_diagram(model::M4SetPointModel) = begin
    edges = Set(model.reaches)
    SetPointDiagram(collect(model.objects), (source, target) -> (source, target) in edges)
end

function write_m4_setpoint_model(
    path::AbstractString,
    model::M4SetPointModel;
    overwrite::Bool=false,
)
    destination = abspath(path)
    mkpath(dirname(destination))
    lock_path = joinpath(dirname(destination), ".$(basename(destination)).write-lock")
    acquired = false
    temporary = nothing
    io = nothing
    try
        try
            mkdir(lock_path)
            acquired = true
        catch err
            (ispath(lock_path) || islink(lock_path)) &&
                throw(ArgumentError("model artifact is already being written"))
            rethrow(err)
        end
        islink(destination) &&
            throw(ArgumentError("model artifact destination must not be a symlink"))
        ispath(destination) && !overwrite &&
            throw(ArgumentError("model artifact already exists"))
        temporary, io = mktemp(dirname(destination))
        write(io, m4_setpoint_model_json(model), "\n")
        close(io)
        mv(temporary, destination; force=overwrite)
    catch
        io !== nothing && isopen(io) && close(io)
        temporary !== nothing && ispath(temporary) && rm(temporary)
        rethrow()
    finally
        acquired && ispath(lock_path) && rm(lock_path; recursive=true)
    end
    destination
end

function _repository_model_path(model_root::AbstractString, model_path::AbstractString)
    root = realpath(model_root)
    candidate = isabspath(model_path) ? String(model_path) : joinpath(root, model_path)
    isfile(candidate) || throw(ArgumentError("model file does not exist: $model_path"))
    actual = realpath(candidate)
    (actual == root || startswith(actual, root * string(Base.Filesystem.path_separator))) ||
        throw(ArgumentError("model file must stay inside model_root"))
    actual
end

"""Evaluate the exact finite no-terminal-setpoint checker (M4b boundary)."""
function run_m4_model_evaluation(
    project_root::AbstractString,
    model_path::AbstractString;
    output_root::AbstractString=project_root,
    model_root::AbstractString=output_root,
    evaluation_id::Union{AbstractString,Nothing}=nothing,
    claim_relation::Symbol=:observation_only,
)
    source = _repository_model_path(model_root, model_path)
    raw_bytes = read(source)
    _run_model_evaluation(
        project_root;
        output_root=output_root,
        evaluation_id=evaluation_id,
        raw_model_bytes=raw_bytes,
        vp_id="VP-BDY-001",
        contract_id="body.no_terminal_setpoint",
        checker_id="check_m4_no_terminal_setpoint",
        failed_predicates_on_reject=["ERIEC.Body.NoTerminalSetPoint"],
        adapter_id="m4-setpoint-model-v1",
        claim_relation=claim_relation,
        numeric_assumptions=(
            carrier_complete=true,
            relation_encoding="closed_world_edge_list",
        ),
    )
end

function _audit_model_evaluation_adapter(
    record::ModelEvaluationRecord,
    source_model_path::AbstractString,
    model_path::AbstractString,
)
    errors = String[]
    record.adapter_id == "m4-setpoint-model-v1" || begin
        push!(errors, "unsupported model evaluation adapter: $(record.adapter_id)")
        return errors
    end
    source_bytes = read(source_model_path)
    model_bytes = read(model_path)
    decoded = try
        _model_evaluation_decode_registered_adapter(record.adapter_id, source_bytes)
    catch
        nothing
    end
    if decoded === nothing
        record.outcome == :error ||
            push!(errors, "invalid M4 source input must have error outcome")
        record.error_stage in (:input_schema, :legacy_unknown) ||
            push!(errors, "invalid M4 source input has an incompatible error stage")
        model_bytes == source_bytes ||
            push!(errors, "invalid M4 input must preserve raw bytes as model snapshot")
        record.fingerprint_algorithm == MODEL_EVALUATION_RAW_FINGERPRINT_ALGORITHM ||
            push!(errors, "invalid M4 input must use the raw-byte fingerprint algorithm")
        return errors
    end
    try
        canonical = Vector{UInt8}(decoded.canonical_bytes)
        model_bytes == canonical ||
            push!(errors, "M4 source does not canonicalize to the model snapshot")
        record.fingerprint_algorithm == M4_SETPOINT_FINGERPRINT_ALGORITHM ||
            push!(errors, "M4 fingerprint algorithm mismatch")
        checker_value = _model_evaluation_registered_adapter_value(
            record.adapter_id,
            decoded.decoded,
        )
        checker_result = _model_evaluation_registered_checker(
            record.checker_id,
            checker_value,
        )
        exact_result = _model_evaluation_registered_exact_outcome(
            record.adapter_id,
            decoded.decoded,
        )
        checker_result == exact_result ||
            push!(errors, "registered M4 checker disagrees with the exact adapter decision")
        expected_outcome = exact_result ? :pass : :reject
        record.outcome == expected_outcome ||
            push!(errors, "M4 outcome does not match the canonical source model")
        expected_failed = expected_outcome == :reject ?
            ["ERIEC.Body.NoTerminalSetPoint"] : String[]
        record.failed_predicates == expected_failed ||
            push!(errors, "M4 failed predicates do not match the registry binding")
    catch err
        push!(errors, "M4 semantic replay failed: $(_model_evaluation_showerror(err))")
    end
    errors
end
