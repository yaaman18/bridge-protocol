import SHA

const OBSERVATION_ARTIFACT_SCHEMA_VERSION = 1

struct ObservationArtifact
    schema_version::Int
    timeseries::Vector{NamedTuple}
    system_fingerprint::String
    phenomenal_claim::Symbol
end

struct ObservationArtifactCollection
    schema_version::Int
    artifacts::Vector{ObservationArtifact}
    phenomenal_claim::Symbol
end

function _validate_observation_record(record)
    required = (:t, :T, :V, :O_hat, :wld)
    missing = [field for field in required if !hasproperty(record, field)]
    isempty(missing) || throw(ArgumentError(
        "observation record is missing channels: " * join(String.(missing), ", "),
    ))
    wld = record.wld
    wld_required = (:basis, :eigenvalues, :dimension, :nontrivial)
    missing_wld = [field for field in wld_required if !hasproperty(wld, field)]
    isempty(missing_wld) || throw(ArgumentError(
        "observation Wld record is missing channels: " * join(String.(missing_wld), ", "),
    ))
    record
end

function ObservationArtifactCollection(
    artifacts::AbstractVector;
    schema_version::Integer=OBSERVATION_ARTIFACT_SCHEMA_VERSION,
    phenomenal_claim::Symbol=:not_certified,
)
    schema_version == OBSERVATION_ARTIFACT_SCHEMA_VERSION ||
        throw(ArgumentError("unsupported observation artifact collection schema version"))
    phenomenal_claim == :not_certified ||
        throw(ArgumentError("phenomenal_claim must be :not_certified"))
    isempty(artifacts) && throw(ArgumentError("artifact collection must be nonempty"))
    collected = ObservationArtifact[artifact for artifact in artifacts]
    all(validate_observation_artifact, collected) ||
        throw(ArgumentError("artifact collection contains an invalid artifact"))
    ObservationArtifactCollection(Int(schema_version), collected, phenomenal_claim)
end

function ObservationArtifact(
    timeseries::AbstractVector,
    system_fingerprint::AbstractString;
    schema_version::Integer=OBSERVATION_ARTIFACT_SCHEMA_VERSION,
    phenomenal_claim::Symbol=:not_certified,
)
    schema_version == OBSERVATION_ARTIFACT_SCHEMA_VERSION ||
        throw(ArgumentError("unsupported observation artifact schema version"))
    phenomenal_claim == :not_certified ||
        throw(ArgumentError("phenomenal_claim must be :not_certified"))
    isempty(system_fingerprint) && throw(ArgumentError("system_fingerprint must be nonempty"))
    records = NamedTuple[_validate_observation_record(record) for record in timeseries]
    ObservationArtifact(Int(schema_version), records, String(system_fingerprint), phenomenal_claim)
end

function observation_system_fingerprint(parts...)
    bytes2hex(SHA.sha256(_json_value(parts)))
end

function observation_record(report::ObservationStructureReport, t)
    wld = report.pipeline.wld_result
    (
        t=t,
        T=report.pipeline.tensor,
        V=report.pipeline.weights,
        O_hat=report.pipeline.weighted_tensor,
        wld=(
            basis=wld.basis,
            eigenvalues=wld.eigenvalues,
            dimension=size(wld.basis, 2),
            nontrivial=world_nontrivial(wld),
        ),
    )
end

function observation_timeseries_artifact(
    reports;
    system_fingerprint::AbstractString,
    times=eachindex(reports),
)
    collected = collect(reports)
    collected_times = collect(times)
    length(collected) == length(collected_times) ||
        throw(ArgumentError("reports and times must have equal length"))
    ObservationArtifact(
        [observation_record(report, t) for (report, t) in zip(collected, collected_times)],
        system_fingerprint,
    )
end

function observation_artifact_payload(artifact::ObservationArtifact)
    (
        kind=:observation_artifact,
        schema_version=artifact.schema_version,
        timeseries=artifact.timeseries,
        system_fingerprint=artifact.system_fingerprint,
        phenomenal_claim=artifact.phenomenal_claim,
        julia_unverified_execution_boundary()...,
        lean_contracts=String[],
        julia_checkers=[:validate_observation_artifact],
        numeric_assumptions=(wld_projection_tolerance=1e-8,),
    )
end

function observation_artifact_collection_payload(
    collection::ObservationArtifactCollection;
    metadata::NamedTuple=NamedTuple(),
)
    reserved = Set((
        :kind,
        :schema_version,
        :artifacts,
        :phenomenal_claim,
        :execution_layer,
        :execution_certified,
        :execution_boundary,
        :execution_note,
        :lean_contracts,
        :julia_checkers,
        :numeric_assumptions,
    ))
    conflicts = intersect(reserved, Set(keys(metadata)))
    isempty(conflicts) || throw(ArgumentError(
        "collection metadata cannot override reserved fields: " *
        join(String.(sort!(collect(conflicts))), ", "),
    ))
    merge(
        (
            kind=:observation_artifact_collection,
            schema_version=collection.schema_version,
            artifacts=[observation_artifact_payload(artifact) for artifact in collection.artifacts],
            phenomenal_claim=collection.phenomenal_claim,
            julia_unverified_execution_boundary()...,
            lean_contracts=String[],
            julia_checkers=[:validate_observation_artifact_collection],
            numeric_assumptions=(artifact_count=length(collection.artifacts),),
        ),
        metadata,
    )
end

observation_artifact_json(artifact::ObservationArtifact) =
    _json_value(observation_artifact_payload(artifact))

observation_artifact_collection_json(
    collection::ObservationArtifactCollection;
    metadata::NamedTuple=NamedTuple(),
) = _json_value(observation_artifact_collection_payload(collection; metadata=metadata))

validate_observation_artifact(artifact::ObservationArtifact) = begin
    ObservationArtifact(
        artifact.timeseries,
        artifact.system_fingerprint;
        schema_version=artifact.schema_version,
        phenomenal_claim=artifact.phenomenal_claim,
    )
    true
end

validate_observation_artifact_collection(collection::ObservationArtifactCollection) = begin
    ObservationArtifactCollection(
        collection.artifacts;
        schema_version=collection.schema_version,
        phenomenal_claim=collection.phenomenal_claim,
    )
    true
end

function certified_observation_artifact(
    artifact::ObservationArtifact,
    check::CertifiedArtifactCheck,
)
    validate_observation_artifact(artifact)
    certified_artifact_envelope(observation_artifact_payload(artifact), check)
end

certified_observation_artifact_json(
    artifact::ObservationArtifact,
    check::CertifiedArtifactCheck,
) = _json_value(certified_observation_artifact(artifact, check))

function certified_observation_artifact_collection(
    collection::ObservationArtifactCollection,
    check::CertifiedArtifactCheck;
    metadata::NamedTuple=NamedTuple(),
)
    certified_artifact_envelope(
        observation_artifact_collection_payload(collection; metadata=metadata),
        check,
    )
end

certified_observation_artifact_collection_json(
    collection::ObservationArtifactCollection,
    check::CertifiedArtifactCheck;
    metadata::NamedTuple=NamedTuple(),
) = _json_value(certified_observation_artifact_collection(
    collection,
    check;
    metadata=metadata,
))

function write_observation_artifact(
    path::AbstractString,
    artifact::ObservationArtifact,
)
    validate_observation_artifact(artifact)
    open(path, "w") do io
        write(io, observation_artifact_json(artifact))
        write(io, "\n")
    end
    path
end

function write_certified_observation_artifact(
    path::AbstractString,
    artifact::ObservationArtifact,
    check::CertifiedArtifactCheck,
)
    open(path, "w") do io
        write(io, certified_observation_artifact_json(artifact, check))
        write(io, "\n")
    end
    path
end

function _artifact_matrix(value)
    rows = collect(value)
    isempty(rows) && return zeros(Float64, 0, 0)
    width = length(first(rows))
    all(row -> length(row) == width, rows) ||
        throw(ArgumentError("artifact matrix rows must have equal length"))
    matrix = Matrix{Float64}(undef, length(rows), width)
    for i in eachindex(rows), j in 1:width
        matrix[i, j] = rows[i][j]
    end
    matrix
end

_artifact_vector(value) = Float64[item for item in value]

function _parsed_observation_record(record)
    _validate_observation_record(record)
    wld = record.wld
    (
        t=record.t,
        T=_artifact_matrix(record.T),
        V=_artifact_vector(record.V),
        O_hat=_artifact_matrix(record.O_hat),
        wld=(
            basis=_artifact_matrix(wld.basis),
            eigenvalues=_artifact_vector(wld.eigenvalues),
            dimension=Int(wld.dimension),
            nontrivial=Bool(wld.nontrivial),
        ),
    )
end

function _parsed_observation_artifact(payload)
    required = (:schema_version, :timeseries, :system_fingerprint, :phenomenal_claim)
    missing = [field for field in required if !haskey(payload, field)]
    isempty(missing) || throw(ArgumentError(
        "observation artifact is missing fields: " * join(String.(missing), ", "),
    ))
    Symbol(String(payload.phenomenal_claim)) == :not_certified ||
        throw(ArgumentError("phenomenal_claim must be :not_certified"))
    ObservationArtifact(
        [_parsed_observation_record(record) for record in payload.timeseries],
        String(payload.system_fingerprint);
        schema_version=Int(payload.schema_version),
        phenomenal_claim=:not_certified,
    )
end

function parse_observation_artifact_json(text::AbstractString)
    root = try
        JSON3.read(text)
    catch err
        throw(ArgumentError("invalid observation artifact JSON: $(sprint(showerror, err))"))
    end
    payload = haskey(root, :payload) ? root.payload : root
    _parsed_observation_artifact(payload)
end

function parse_observation_artifact_collection_json(text::AbstractString)
    root = try
        JSON3.read(text)
    catch err
        throw(ArgumentError(
            "invalid observation artifact collection JSON: $(sprint(showerror, err))",
        ))
    end
    payload = haskey(root, :payload) ? root.payload : root
    required = (:schema_version, :artifacts, :phenomenal_claim)
    missing = [field for field in required if !haskey(payload, field)]
    isempty(missing) || throw(ArgumentError(
        "observation artifact collection is missing fields: " * join(String.(missing), ", "),
    ))
    Symbol(String(payload.phenomenal_claim)) == :not_certified ||
        throw(ArgumentError("phenomenal_claim must be :not_certified"))
    artifacts = [_parsed_observation_artifact(artifact) for artifact in payload.artifacts]
    ObservationArtifactCollection(
        artifacts;
        schema_version=Int(payload.schema_version),
        phenomenal_claim=:not_certified,
    )
end

function _artifact_wld_projection(record)
    basis = record.wld.basis
    basis * transpose(basis)
end

function umwelt_relative_diff(
    first::ObservationArtifact,
    second::ObservationArtifact;
    diff_tol::Real=1e-6,
)
    fingerprints_differ = first.system_fingerprint != second.system_fingerprint
    if isempty(first.timeseries) != isempty(second.timeseries)
        return (relative=fingerprints_differ, projection_norm_diff=Inf)
    end
    isempty(first.timeseries) &&
        return (relative=false, projection_norm_diff=0.0)
    first_projection = _artifact_wld_projection(last(first.timeseries))
    second_projection = _artifact_wld_projection(last(second.timeseries))
    if size(first_projection) != size(second_projection)
        return (relative=fingerprints_differ, projection_norm_diff=Inf)
    end
    projection_norm_diff = Float64(norm(first_projection - second_projection))
    (
        relative=fingerprints_differ && projection_norm_diff > diff_tol,
        projection_norm_diff=projection_norm_diff,
    )
end
