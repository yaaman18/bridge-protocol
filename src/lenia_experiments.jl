struct LeniaExperimentPreset
    name::Symbol
    shape::Tuple{Int,Int}
    action_count::Int
    feature_counts::Vector{Int}
    kernel_size::Int
    tau_steps::Vector{Int}
    acceptance::ExperimentAcceptanceConfig
    initial_condition::LeniaInitialConditionConfig
    description::String

    function LeniaExperimentPreset(
        name::Symbol,
        shape::Tuple{Int,Int},
        action_count::Int,
        feature_counts::Vector{Int},
        kernel_size::Int,
        tau_steps::Vector{Int},
        acceptance::ExperimentAcceptanceConfig,
        initial_condition::LeniaInitialConditionConfig,
        description::String,
    )
        all(dimension -> dimension > 0, shape) ||
            throw(ArgumentError("Lenia preset shape dimensions must be positive"))
        action_count > 0 ||
            throw(ArgumentError("Lenia preset action_count must be positive"))
        !isempty(feature_counts) && all(value -> value in (6, 32, 64), feature_counts) ||
            throw(ArgumentError(
                "Lenia preset feature_counts must contain only 6, 32, or 64",
            ))
        kernel_size > 0 && isodd(kernel_size) ||
            throw(ArgumentError("Lenia preset kernel_size must be positive and odd"))
        !isempty(tau_steps) && all(value -> value > 0, tau_steps) ||
            throw(ArgumentError("Lenia preset tau_steps must be positive"))
        isempty(description) &&
            throw(ArgumentError("Lenia preset description must not be empty"))
        new(
            name,
            shape,
            action_count,
            feature_counts,
            kernel_size,
            tau_steps,
            acceptance,
            initial_condition,
            description,
        )
    end
end

struct LeniaExperimentSweepResult{E,S,P}
    experiments::E
    summary::S
    artifact_paths::P
end

const _LENIA_EXPERIMENT_SUMMARY_FIELDS = (
    :tau_step,
    :feature_count,
    :shape_rows,
    :shape_cols,
    :action_count,
    :kernel_size,
    :seed,
    :repeats,
    :relative_tolerance,
    :lambda_threshold,
    :eig_tol,
    :initial_mode,
    :initial_baseline,
    :initial_amplitude,
    :initial_width,
    :system_fingerprint,
    :artifact_sha256,
    :certified,
    :accepted,
    :dominant_eigenvalue,
    :max_relative_deviation,
    :status,
)

function LeniaExperimentPreset(
    name::Symbol,
    shape::Tuple{Int,Int},
    action_count::Integer,
    feature_counts,
    kernel_size::Integer,
    tau_steps,
    acceptance::ExperimentAcceptanceConfig,
    description::AbstractString,
)
    features = Int.(collect(feature_counts))
    taus = Int.(collect(tau_steps))
    LeniaExperimentPreset(
        name,
        shape,
        Int(action_count),
        features,
        Int(kernel_size),
        taus,
        acceptance,
        LeniaInitialConditionConfig(),
        String(description),
    )
end

function LeniaExperimentPreset(
    name::Symbol,
    shape::Tuple{Int,Int},
    action_count::Integer,
    feature_counts,
    kernel_size::Integer,
    tau_steps,
    acceptance::ExperimentAcceptanceConfig,
    initial_condition::LeniaInitialConditionConfig,
    description::AbstractString,
)
    LeniaExperimentPreset(
        name,
        shape,
        Int(action_count),
        Int.(collect(feature_counts)),
        Int(kernel_size),
        Int.(collect(tau_steps)),
        acceptance,
        initial_condition,
        String(description),
    )
end

function lenia_experiment_preset_catalog()
    acceptance = ExperimentAcceptanceConfig()
    (
        smoke=LeniaExperimentPreset(
            :smoke,
            (3, 3),
            2,
            [6],
            3,
            [1],
            acceptance,
            "Fast prototype profile for CI and local integration checks.",
        ),
        short=LeniaExperimentPreset(
            :short,
            (8, 8),
            16,
            [6, 32],
            5,
            [1, 2, 4],
            acceptance,
            "Production-action profile for bounded exploratory sweeps.",
        ),
        long=LeniaExperimentPreset(
            :long,
            (32, 32),
            24,
            [32, 64],
            9,
            [1, 2, 4, 8, 16],
            acceptance,
            "Long production profile for persisted offline experiments.",
        ),
    )
end

function lenia_experiment_preset(name::Symbol)
    catalog = lenia_experiment_preset_catalog()
    hasproperty(catalog, name) ||
        throw(ArgumentError("unknown Lenia experiment preset: $name"))
    getproperty(catalog, name)
end

function _parse_lenia_preset_shape(value)
    parts = split(replace(string(value), "x" => ",", "X" => ","), ",")
    length(parts) == 2 || throw(ArgumentError("shape must contain rows and columns"))
    shape = (parse(Int, strip(parts[1])), parse(Int, strip(parts[2])))
    all(dimension -> dimension > 0, shape) ||
        throw(ArgumentError("shape dimensions must be positive"))
    shape
end

function read_lenia_experiment_preset(path::AbstractString)
    values = _read_key_value_file(path)
    base = lenia_experiment_preset(:smoke)
    name = Symbol(_preset_value(values, "name", _preset_file_name(path)))
    shape = _parse_lenia_preset_shape(_preset_value(
        values,
        "shape",
        "$(base.shape[1])x$(base.shape[2])",
    ))
    action_count = _parse_preset_int(
        _preset_value(values, "action_count", base.action_count),
        "action_count",
    )
    feature_counts = _parse_preset_int_list(
        _preset_value(values, "feature_counts", join(base.feature_counts, ",")),
        "feature_counts",
    )
    kernel_size = _parse_preset_int(
        _preset_value(values, "kernel_size", base.kernel_size),
        "kernel_size",
    )
    tau_steps = _parse_preset_int_list(
        _preset_value(values, "tau_steps", join(base.tau_steps, ",")),
        "tau_steps",
    )
    acceptance = ExperimentAcceptanceConfig(
        lambda_threshold=parse(Float64, string(_preset_value(
            values,
            "lambda_threshold",
            base.acceptance.lambda_threshold,
        ))),
        eig_tol=parse(Float64, string(_preset_value(
            values,
            "eig_tol",
            base.acceptance.eig_tol,
        ))),
        seed=parse(Int, string(_preset_value(values, "seed", base.acceptance.seed))),
        repeats=_parse_preset_int(
            _preset_value(values, "repeats", base.acceptance.repeats),
            "repeats",
        ),
        relative_tolerance=parse(Float64, string(_preset_value(
            values,
            "relative_tolerance",
            base.acceptance.relative_tolerance,
        ))),
    )
    initial_condition = LeniaInitialConditionConfig(
        mode=Symbol(_preset_value(
            values,
            "initial_mode",
            base.initial_condition.mode,
        )),
        seed=acceptance.seed,
        baseline=parse(Float64, string(_preset_value(
            values,
            "initial_baseline",
            base.initial_condition.baseline,
        ))),
        amplitude=parse(Float64, string(_preset_value(
            values,
            "initial_amplitude",
            base.initial_condition.amplitude,
        ))),
        width=parse(Float64, string(_preset_value(
            values,
            "initial_width",
            base.initial_condition.width,
        ))),
    )
    description = String(_preset_value(
        values,
        "description",
        "External Lenia experiment preset loaded from " * String(path),
    ))
    LeniaExperimentPreset(
        name,
        shape,
        action_count,
        feature_counts,
        kernel_size,
        tau_steps,
        acceptance,
        initial_condition,
        description,
    )
end

function lenia_experiment_preset_certificate(preset::LeniaExperimentPreset)
    condition_count = length(preset.tau_steps) * length(preset.feature_counts)
    (
        kind=:LeniaExperimentPreset,
        ok=condition_count > 0 &&
            all(value -> value > 0, preset.tau_steps) &&
            all(value -> value in (6, 32, 64), preset.feature_counts),
        lean_contracts=String[],
        julia_checkers=[
            :lenia_experiment_preset_certificate,
            :read_lenia_experiment_preset,
            :run_lenia_experiment_sweep,
            :reproducibility_assessment,
        ],
        numeric_assumptions=(
            shape=collect(preset.shape),
            action_count=preset.action_count,
            feature_counts=preset.feature_counts,
            kernel_size=preset.kernel_size,
            tau_steps=preset.tau_steps,
            seed=preset.acceptance.seed,
            repeats=preset.acceptance.repeats,
            relative_tolerance=preset.acceptance.relative_tolerance,
            lambda_threshold=preset.acceptance.lambda_threshold,
            eig_tol=preset.acceptance.eig_tol,
            initial_mode=preset.initial_condition.mode,
            initial_baseline=preset.initial_condition.baseline,
            initial_amplitude=preset.initial_condition.amplitude,
            initial_width=preset.initial_condition.width,
        ),
        name=preset.name,
        condition_count=condition_count,
        production_action_dimension=16 <= preset.action_count <= 24,
    )
end

function _lenia_experiment_run_indices(preset::LeniaExperimentPreset, run_indices)
    condition_count = length(preset.tau_steps) * length(preset.feature_counts)
    run_indices === nothing && return collect(1:condition_count)
    selected = Int.(collect(run_indices))
    !isempty(selected) || throw(ArgumentError("run_indices must contain at least one index"))
    length(unique(selected)) == length(selected) ||
        throw(ArgumentError("run_indices must not contain duplicates"))
    all(index -> 1 <= index <= condition_count, selected) ||
        throw(ArgumentError("run_indices must be between 1 and $condition_count"))
    sort(selected)
end

function lenia_experiment_plan(
    preset::LeniaExperimentPreset;
    acceptance_config::ExperimentAcceptanceConfig=preset.acceptance,
    initial_condition::LeniaInitialConditionConfig=preset.initial_condition,
    run_indices=nothing,
)
    selected = _lenia_experiment_run_indices(preset, run_indices)
    selected_set = Set(selected)
    conditions = NamedTuple[]
    index = 0
    for tau_step in preset.tau_steps
        for feature_count in preset.feature_counts
            index += 1
            index in selected_set || continue
            push!(conditions, (
                index=index,
                tau_step=tau_step,
                feature_count=feature_count,
                repetitions=acceptance_config.repeats,
            ))
        end
    end
    total_condition_count = length(preset.tau_steps) * length(preset.feature_counts)
    (
        kind=:LeniaExperimentPlan,
        preset=preset.name,
        shape=collect(preset.shape),
        action_count=preset.action_count,
        kernel_size=preset.kernel_size,
        initial_condition=(
            mode=initial_condition.mode,
            baseline=initial_condition.baseline,
            amplitude=initial_condition.amplitude,
            width=initial_condition.width,
        ),
        total_condition_count=total_condition_count,
        selected_condition_count=length(conditions),
        selected_run_indices=selected,
        repetitions_per_condition=acceptance_config.repeats,
        total_architecture_runs=total_condition_count * acceptance_config.repeats,
        selected_architecture_runs=length(conditions) * acceptance_config.repeats,
        conditions=conditions,
    )
end

function _lenia_experiment_run_dir(output_dir::AbstractString, index::Integer)
    joinpath(output_dir, "run-" * lpad(string(index), 3, '0'))
end

function _write_lenia_experiment_run(
    run_dir::AbstractString,
    artifact_json,
    summary;
    certificate_json=nothing,
)
    mkpath(run_dir)
    artifact_path = joinpath(run_dir, "artifact.json")
    summary_path = joinpath(run_dir, "summary.json")
    summary_tsv_path = joinpath(run_dir, "summary.tsv")
    certificate_path = certificate_json === nothing ? nothing :
        joinpath(run_dir, "certificate.json")
    open(artifact_path, "w") do io
        write(io, artifact_json)
        write(io, "\n")
    end
    open(summary_path, "w") do io
        write(io, _json_value(summary))
        write(io, "\n")
    end
    open(summary_tsv_path, "w") do io
        for field in _LENIA_EXPERIMENT_SUMMARY_FIELDS
            println(io, String(field), '\t', getproperty(summary, field))
        end
    end
    if certificate_path !== nothing
        open(certificate_path, "w") do io
            write(io, certificate_json)
            write(io, "\n")
        end
    end
    (
        output_dir=String(run_dir),
        artifact_path=artifact_path,
        summary_path=summary_path,
        summary_tsv_path=summary_tsv_path,
        certificate_path=certificate_path,
    )
end

function _read_lenia_experiment_run(path::AbstractString)
    values = Dict{String,String}()
    for line in eachline(path)
        parts = split(line, '\t'; limit=2)
        length(parts) == 2 || throw(ArgumentError("invalid Lenia run summary line: $line"))
        values[parts[1]] = parts[2]
    end
    required = [
        "tau_step", "feature_count", "shape_rows", "shape_cols", "action_count",
        "kernel_size", "seed", "repeats", "relative_tolerance", "lambda_threshold",
        "eig_tol", "initial_mode", "initial_baseline", "initial_amplitude",
        "initial_width", "certified", "accepted", "dominant_eigenvalue",
        "max_relative_deviation", "status",
    ]
    all(key -> haskey(values, key), required) ||
        throw(ArgumentError("Lenia run summary is missing required fields"))
    (
        tau_step=parse(Int, values["tau_step"]),
        feature_count=parse(Int, values["feature_count"]),
        shape_rows=parse(Int, values["shape_rows"]),
        shape_cols=parse(Int, values["shape_cols"]),
        action_count=parse(Int, values["action_count"]),
        kernel_size=parse(Int, values["kernel_size"]),
        seed=parse(Int, values["seed"]),
        repeats=parse(Int, values["repeats"]),
        relative_tolerance=parse(Float64, values["relative_tolerance"]),
        lambda_threshold=parse(Float64, values["lambda_threshold"]),
        eig_tol=parse(Float64, values["eig_tol"]),
        initial_mode=Symbol(values["initial_mode"]),
        initial_baseline=parse(Float64, values["initial_baseline"]),
        initial_amplitude=parse(Float64, values["initial_amplitude"]),
        initial_width=parse(Float64, values["initial_width"]),
        system_fingerprint=get(values, "system_fingerprint", ""),
        artifact_sha256=get(values, "artifact_sha256", ""),
        certified=values["certified"] == "true",
        accepted=values["accepted"] == "true",
        dominant_eigenvalue=parse(Float64, values["dominant_eigenvalue"]),
        max_relative_deviation=parse(Float64, values["max_relative_deviation"]),
        status=Symbol(values["status"]),
    )
end

function _lenia_experiment_resume_matches(
    summary,
    preset,
    tau_step,
    feature_count,
    acceptance,
    initial_condition::LeniaInitialConditionConfig,
    certified::Bool,
)
    summary.tau_step == tau_step &&
        summary.feature_count == feature_count &&
        (summary.shape_rows, summary.shape_cols) == preset.shape &&
        summary.action_count == preset.action_count &&
        summary.kernel_size == preset.kernel_size &&
        summary.seed == acceptance.seed &&
        summary.repeats == acceptance.repeats &&
        summary.relative_tolerance == acceptance.relative_tolerance &&
        summary.lambda_threshold == acceptance.lambda_threshold &&
        summary.eig_tol == acceptance.eig_tol &&
        summary.initial_mode == initial_condition.mode &&
        summary.initial_baseline == initial_condition.baseline &&
        summary.initial_amplitude == initial_condition.amplitude &&
        summary.initial_width == initial_condition.width &&
        !isempty(summary.system_fingerprint) &&
        !isempty(summary.artifact_sha256) &&
        summary.certified == certified
end

function _lenia_experiment_run_artifacts(run_dir::AbstractString)
    (
        artifact_path=joinpath(run_dir, "artifact.json"),
        summary_path=joinpath(run_dir, "summary.json"),
        summary_tsv_path=joinpath(run_dir, "summary.tsv"),
    )
end

function _lenia_experiment_missing_artifacts(run_dir::AbstractString)
    paths = _lenia_experiment_run_artifacts(run_dir)
    [String(key) for key in keys(paths) if !isfile(getproperty(paths, key))]
end

function lenia_observation_artifact_audit(
    path::AbstractString;
    expected_system_fingerprint::Union{AbstractString,Nothing}=nothing,
    expected_artifact_count::Union{Integer,Nothing}=nothing,
    expected_dominant_eigenvalue::Union{Real,Nothing}=nothing,
    expected_sha256::Union{AbstractString,Nothing}=nothing,
    eigenvalue_tolerance::Real=1e-12,
)
    expected_artifact_count === nothing || expected_artifact_count >= 1 ||
        throw(ArgumentError("expected_artifact_count must be positive"))
    eigenvalue_tolerance >= 0 ||
        throw(ArgumentError("eigenvalue_tolerance must be nonnegative"))
    artifact_path = String(path)
    exists = isfile(artifact_path)
    artifact_text = exists ? read(artifact_path, String) : ""
    content_sha256 = exists ? bytes2hex(SHA.sha256(chomp(artifact_text))) : nothing
    sha256_ok = expected_sha256 === nothing || content_sha256 == String(expected_sha256)
    collection = nothing
    parse_error = nothing
    certified_envelope = false
    envelope_audit = nothing
    if exists
        try
            root = JSON3.read(artifact_text)
            certified_envelope = haskey(root, :certificate) || haskey(root, :trust)
            envelope_audit = certified_envelope ?
                certified_json_artifact_audit(
                    artifact_path;
                    expected_kind=:observation_artifact_collection,
                ) : nothing
            collection = parse_observation_artifact_collection_json(
                artifact_text,
            )
        catch err
            parse_error = sprint(showerror, err)
        end
    end
    marker_ok = collection !== nothing &&
        collection.phenomenal_claim == :not_certified &&
        all(artifact -> artifact.phenomenal_claim == :not_certified, collection.artifacts)
    envelope_ok = envelope_audit === nothing || envelope_audit.ok
    fingerprints = collection === nothing ? String[] :
        [artifact.system_fingerprint for artifact in collection.artifacts]
    fingerprint_ok = expected_system_fingerprint === nothing ||
        (!isempty(fingerprints) && all(==(String(expected_system_fingerprint)), fingerprints))
    artifact_count_ok = expected_artifact_count === nothing ||
        length(fingerprints) == expected_artifact_count
    dominant_eigenvalues = collection === nothing ? Float64[] : [
        isempty(artifact.timeseries) || isempty(last(artifact.timeseries).wld.eigenvalues) ?
            NaN : maximum(real.(last(artifact.timeseries).wld.eigenvalues))
        for artifact in collection.artifacts
    ]
    dominant_eigenvalue_ok = expected_dominant_eigenvalue === nothing ||
        (!isempty(dominant_eigenvalues) && all(
            value -> isfinite(value) && isapprox(
                value,
                expected_dominant_eigenvalue;
                atol=eigenvalue_tolerance,
                rtol=eigenvalue_tolerance,
            ),
            dominant_eigenvalues,
        ))
    (
        kind=:LeniaObservationArtifactAudit,
        ok=exists && collection !== nothing && marker_ok && envelope_ok &&
            fingerprint_ok && artifact_count_ok && dominant_eigenvalue_ok && sha256_ok,
        path=artifact_path,
        exists=exists,
        parse_ok=collection !== nothing,
        parse_error=parse_error,
        certified_envelope=certified_envelope,
        envelope_ok=envelope_ok,
        envelope_audit=envelope_audit,
        artifact_count=length(fingerprints),
        expected_artifact_count=expected_artifact_count,
        artifact_count_ok=artifact_count_ok,
        system_fingerprints=fingerprints,
        expected_system_fingerprint=expected_system_fingerprint,
        system_fingerprint_ok=fingerprint_ok,
        dominant_eigenvalues=dominant_eigenvalues,
        expected_dominant_eigenvalue=expected_dominant_eigenvalue,
        dominant_eigenvalue_ok=dominant_eigenvalue_ok,
        eigenvalue_tolerance=Float64(eigenvalue_tolerance),
        content_sha256=content_sha256,
        expected_sha256=expected_sha256,
        sha256_ok=sha256_ok,
        phenomenal_claim_ok=marker_ok,
    )
end

lenia_observation_artifact_audit_json(path::AbstractString; kwargs...) =
    _json_value(lenia_observation_artifact_audit(path; kwargs...))

function _lenia_summary_field_matches(actual, expected)
    actual isa AbstractString && return String(actual) == string(expected)
    expected isa AbstractFloat && return isapprox(
        Float64(actual),
        expected;
        atol=1e-12,
        rtol=1e-12,
    )
    actual == expected
end

function lenia_experiment_summary_audit(path::AbstractString, expected::NamedTuple)
    summary_path = String(path)
    exists = isfile(summary_path)
    parsed = nothing
    parse_error = nothing
    if exists
        try
            parsed = JSON3.read(read(summary_path, String))
        catch err
            parse_error = sprint(showerror, err)
        end
    end
    missing_fields = parsed === nothing ? collect(_LENIA_EXPERIMENT_SUMMARY_FIELDS) : [
        field for field in _LENIA_EXPERIMENT_SUMMARY_FIELDS if !haskey(parsed, field)
    ]
    mismatched_fields = parsed === nothing ? Symbol[] : [
        field for field in _LENIA_EXPERIMENT_SUMMARY_FIELDS
        if haskey(parsed, field) &&
            (!_lenia_summary_field_matches(getproperty(parsed, field), getproperty(expected, field)))
    ]
    (
        kind=:LeniaExperimentSummaryAudit,
        ok=exists && parsed !== nothing && isempty(missing_fields) &&
            isempty(mismatched_fields),
        path=summary_path,
        exists=exists,
        parse_ok=parsed !== nothing,
        parse_error=parse_error,
        missing_fields=missing_fields,
        mismatched_fields=mismatched_fields,
    )
end

lenia_experiment_summary_audit_json(path::AbstractString, expected::NamedTuple) =
    _json_value(lenia_experiment_summary_audit(path, expected))

function _lenia_experiment_report_entry(entry)
    run_dir = entry.output_dir
    missing = run_dir === nothing ? String[] : _lenia_experiment_missing_artifacts(run_dir)
    artifact_path = run_dir === nothing ? nothing : joinpath(run_dir, "artifact.json")
    expected_fingerprint = hasproperty(entry, :system_fingerprint) &&
        !isempty(entry.system_fingerprint) ? entry.system_fingerprint : nothing
    expected_dominant_eigenvalue = hasproperty(entry, :dominant_eigenvalue) ?
        entry.dominant_eigenvalue : nothing
    expected_sha256 = hasproperty(entry, :artifact_sha256) &&
        !isempty(entry.artifact_sha256) ? entry.artifact_sha256 : nothing
    artifact_audit = artifact_path === nothing ? nothing :
        lenia_observation_artifact_audit(
            artifact_path;
            expected_system_fingerprint=expected_fingerprint,
            expected_artifact_count=1,
            expected_dominant_eigenvalue=expected_dominant_eigenvalue,
            expected_sha256=expected_sha256,
        )
    if artifact_audit !== nothing && artifact_audit.exists && !artifact_audit.ok
        push!(missing, "artifact_invalid")
    end
    summary_path = run_dir === nothing ? nothing : joinpath(run_dir, "summary.json")
    summary_audit = summary_path === nothing ? nothing :
        lenia_experiment_summary_audit(summary_path, entry)
    if summary_audit !== nothing && summary_audit.exists && !summary_audit.ok
        push!(missing, "summary_invalid")
    end
    certificate_path = run_dir === nothing ? nothing : joinpath(run_dir, "certificate.json")
    certification_requested = hasproperty(entry, :certified) && entry.certified
    certificate_audit = certification_requested && certificate_path !== nothing ?
        certified_json_artifact_audit(
            certificate_path;
            expected_kind=:LeniaParameterGrid,
        ) : nothing
    if hasproperty(entry, :certified) && entry.certified &&
            certificate_path !== nothing && !isfile(certificate_path)
        push!(missing, "certificate_path")
    end
    if certificate_audit !== nothing && certificate_audit.exists && !certificate_audit.ok
        push!(missing, "certificate_invalid")
    end
    merge(entry, (
        certificate_path=certificate_path,
        certificate_exists=certificate_path !== nothing && isfile(certificate_path),
        certificate_valid=certificate_audit === nothing ? nothing : certificate_audit.ok,
        certificate_parse_error=certificate_audit === nothing ? nothing :
            certificate_audit.parse_error,
        certificate_audit=certificate_audit,
        artifact_exists=artifact_audit !== nothing && artifact_audit.exists,
        artifact_valid=artifact_audit !== nothing && artifact_audit.ok,
        artifact_parse_error=artifact_audit === nothing ? nothing : artifact_audit.parse_error,
        artifact_audit=artifact_audit,
        summary_exists=summary_audit !== nothing && summary_audit.exists,
        summary_valid=summary_audit !== nothing && summary_audit.ok,
        summary_parse_error=summary_audit === nothing ? nothing : summary_audit.parse_error,
        summary_audit=summary_audit,
        artifact_complete=isempty(missing),
        missing_artifacts=missing,
    ))
end

function _write_lenia_experiment_sweep(output_dir::AbstractString, summary)
    mkpath(output_dir)
    summary_path = joinpath(output_dir, "summary.json")
    manifest_path = joinpath(output_dir, "manifest.json")
    certificate_graph_path = joinpath(output_dir, "certificate-graph.json")
    envelope_audit_path = joinpath(output_dir, "envelope-audit.json")
    dashboard_path = joinpath(output_dir, "dashboard.html")
    open(summary_path, "w") do io
        write(io, _json_value(summary))
        write(io, "\n")
    end
    directory_report = lenia_experiment_sweep_report(output_dir)
    manifest = (
        schema_version=1,
        kind=:LeniaExperimentSweepManifest,
        preset=summary.preset,
        run_count=directory_report.run_count,
        accepted_count=directory_report.accepted_count,
        resumed_count=summary.resumed_count,
        entries=directory_report.entries,
    )
    open(manifest_path, "w") do io
        write(io, _json_value(manifest))
        write(io, "\n")
    end
    open(certificate_graph_path, "w") do io
        write(io, _json_value(_lenia_experiment_certificate_graph(
            directory_report.entries,
            output_dir,
        )))
        write(io, "\n")
    end
    open(envelope_audit_path, "w") do io
        write(io, _json_value(lenia_experiment_sweep_certified_envelope_audit(output_dir)))
        write(io, "\n")
    end
    write_lenia_experiment_dashboard(dashboard_path, directory_report)
    (
        output_dir=String(output_dir),
        summary_path=summary_path,
        manifest_path=manifest_path,
        certificate_graph_path=certificate_graph_path,
        envelope_audit_path=envelope_audit_path,
        dashboard_path=dashboard_path,
    )
end

function _lenia_experiment_certificate_graph(entries, output_dir)
    nodes = [
        (
            id="run-$(lpad(string(entry.index), 3, '0'))",
            certified=hasproperty(entry, :certified) && entry.certified,
            certificate_path=hasproperty(entry, :certificate_path) ?
                entry.certificate_path : joinpath(
                    output_dir,
                    "run-$(lpad(string(entry.index), 3, '0'))",
                    "certificate.json",
                ),
        )
        for entry in entries
    ]
    requested = count(node -> node.certified, nodes)
    existing = count(
        node -> node.certified && node.certificate_path !== nothing &&
            isfile(node.certificate_path),
        nodes,
    )
    (
        kind=:LeniaExperimentSweepCertificateGraph,
        output_dir=String(output_dir),
        run_count=length(nodes),
        certification_requested_count=requested,
        certificate_complete_count=existing,
        missing_certificate_count=requested - existing,
        nodes=nodes,
        edges=[
            (from="manifest", to=node.id, relation=:contains_condition)
            for node in nodes
        ],
    )
end

function lenia_experiment_sweep_certificate_graph(sweep::LeniaExperimentSweepResult)
    output_dir = hasproperty(sweep.artifact_paths, :output_dir) ?
        sweep.artifact_paths.output_dir : ""
    _lenia_experiment_certificate_graph(sweep.summary.entries, output_dir)
end

function lenia_experiment_sweep_certificate_graph(output_dir::AbstractString)
    report = lenia_experiment_sweep_report(output_dir)
    _lenia_experiment_certificate_graph(report.entries, output_dir)
end

lenia_experiment_sweep_certificate_graph_json(sweep_or_output_dir) =
    _json_value(lenia_experiment_sweep_certificate_graph(sweep_or_output_dir))

function write_lenia_experiment_sweep_certificate_graph(
    path::AbstractString,
    sweep_or_output_dir,
)
    open(path, "w") do io
        write(io, lenia_experiment_sweep_certificate_graph_json(sweep_or_output_dir))
        write(io, "\n")
    end
    path
end

function lenia_experiment_sweep_certified_envelope_audit(graph::NamedTuple)
    certified_nodes = filter(node -> node.certified, graph.nodes)
    audits = [
        certified_json_artifact_audit(
            node.certificate_path;
            expected_kind=:LeniaParameterGrid,
        )
        for node in certified_nodes
    ]
    (
        kind=:LeniaExperimentSweepCertifiedEnvelopeAudit,
        ok=length(audits) == graph.certification_requested_count &&
            all(audit -> audit.ok, audits),
        output_dir=graph.output_dir,
        requested_count=graph.certification_requested_count,
        audit_count=length(audits),
        failed_count=count(audit -> !audit.ok, audits),
        audits=audits,
    )
end

lenia_experiment_sweep_certified_envelope_audit(sweep::LeniaExperimentSweepResult) =
    lenia_experiment_sweep_certified_envelope_audit(
        lenia_experiment_sweep_certificate_graph(sweep),
    )

lenia_experiment_sweep_certified_envelope_audit(output_dir::AbstractString) =
    lenia_experiment_sweep_certified_envelope_audit(
        lenia_experiment_sweep_certificate_graph(output_dir),
    )

lenia_experiment_sweep_certified_envelope_audit_json(sweep_or_output_dir) =
    _json_value(lenia_experiment_sweep_certified_envelope_audit(sweep_or_output_dir))

function write_lenia_experiment_sweep_certified_envelope_audit(
    path::AbstractString,
    sweep_or_output_dir,
)
    open(path, "w") do io
        write(io, lenia_experiment_sweep_certified_envelope_audit_json(sweep_or_output_dir))
        write(io, "\n")
    end
    path
end

function lenia_experiment_sweep_report(sweep::LeniaExperimentSweepResult)
    entries = [_lenia_experiment_report_entry(entry) for entry in sweep.summary.entries]
    (
        kind=:LeniaExperimentSweepReport,
        output_dir=hasproperty(sweep.artifact_paths, :output_dir) ?
            sweep.artifact_paths.output_dir : nothing,
        preset=sweep.summary.preset,
        run_count=length(entries),
        accepted_count=count(entry -> entry.accepted, entries),
        resumed_count=sweep.summary.resumed_count,
        artifact_complete_count=count(entry -> entry.artifact_complete, entries),
        missing_artifact_count=sum(length(entry.missing_artifacts) for entry in entries),
        invalid_artifact_count=count(
            entry -> entry.artifact_exists && !entry.artifact_valid,
            entries,
        ),
        invalid_certificate_count=count(
            entry -> entry.certificate_valid === false && entry.certificate_exists,
            entries,
        ),
        invalid_summary_count=count(
            entry -> entry.summary_exists && !entry.summary_valid,
            entries,
        ),
        entries=entries,
    )
end

function lenia_experiment_sweep_report(output_dir::AbstractString)
    isdir(output_dir) ||
        throw(ArgumentError("Lenia sweep output_dir does not exist: $output_dir"))
    entries = NamedTuple[]
    for name in sort(readdir(output_dir))
        matched = match(r"^run-(\d+)$", name)
        matched === nothing && continue
        run_dir = joinpath(output_dir, name)
        isdir(run_dir) || continue
        paths = _lenia_experiment_run_artifacts(run_dir)
        if isfile(paths.summary_tsv_path)
            stored = _read_lenia_experiment_run(paths.summary_tsv_path)
            push!(entries, _lenia_experiment_report_entry(merge(stored, (
                index=parse(Int, matched.captures[1]),
                resumed=false,
                output_dir=run_dir,
                artifact_path=paths.artifact_path,
                summary_path=paths.summary_path,
                summary_tsv_path=paths.summary_tsv_path,
            ))))
        else
            artifact_audit = lenia_observation_artifact_audit(paths.artifact_path)
            missing = _lenia_experiment_missing_artifacts(run_dir)
            if artifact_audit.exists && !artifact_audit.ok
                push!(missing, "artifact_invalid")
            end
            push!(entries, (
                index=parse(Int, matched.captures[1]),
                accepted=false,
                resumed=false,
                output_dir=run_dir,
                artifact_exists=artifact_audit.exists,
                artifact_valid=artifact_audit.ok,
                artifact_parse_error=artifact_audit.parse_error,
                artifact_audit=artifact_audit,
                certificate_exists=false,
                certificate_valid=nothing,
                certificate_parse_error=nothing,
                certificate_audit=nothing,
                summary_exists=isfile(paths.summary_path),
                summary_valid=false,
                summary_parse_error=nothing,
                summary_audit=nothing,
                artifact_complete=false,
                missing_artifacts=missing,
            ))
        end
    end
    summary_path = joinpath(output_dir, "summary.json")
    (
        kind=:LeniaExperimentSweepReport,
        output_dir=String(output_dir),
        preset=nothing,
        run_count=length(entries),
        accepted_count=count(entry -> entry.accepted, entries),
        resumed_count=nothing,
        artifact_complete_count=count(entry -> entry.artifact_complete, entries),
        missing_artifact_count=sum(length(entry.missing_artifacts) for entry in entries),
        invalid_artifact_count=count(
            entry -> entry.artifact_exists && !entry.artifact_valid,
            entries,
        ),
        invalid_certificate_count=count(
            entry -> entry.certificate_valid === false && entry.certificate_exists,
            entries,
        ),
        invalid_summary_count=count(
            entry -> entry.summary_exists && !entry.summary_valid,
            entries,
        ),
        summary_exists=isfile(summary_path),
        entries=entries,
    )
end

lenia_experiment_sweep_report_json(sweep::LeniaExperimentSweepResult) =
    _json_value(lenia_experiment_sweep_report(sweep))

lenia_experiment_sweep_report_json(output_dir::AbstractString) =
    _json_value(lenia_experiment_sweep_report(output_dir))

function write_lenia_experiment_sweep_report(
    path::AbstractString,
    sweep_or_output_dir,
)
    open(path, "w") do io
        write(io, lenia_experiment_sweep_report_json(sweep_or_output_dir))
        write(io, "\n")
    end
    path
end

function run_lenia_experiment_sweep(
    preset::LeniaExperimentPreset;
    output_dir::Union{AbstractString,Nothing}=nothing,
    resume::Bool=false,
    acceptance_config::ExperimentAcceptanceConfig=preset.acceptance,
    certificate_check::Union{CertifiedArtifactCheck,Nothing}=nothing,
    initial_condition::LeniaInitialConditionConfig=preset.initial_condition,
    run_indices=nothing,
    kwargs...,
)
    plan = lenia_experiment_plan(
        preset;
        acceptance_config=acceptance_config,
        initial_condition=initial_condition,
        run_indices=run_indices,
    )
    selected_indices = Set(plan.selected_run_indices)
    experiments = Any[]
    entries = NamedTuple[]
    run_index = 0
    for tau_step in preset.tau_steps
        for feature_count in preset.feature_counts
            run_index += 1
            run_index in selected_indices || continue
            run_dir = output_dir === nothing ? nothing :
                _lenia_experiment_run_dir(output_dir, run_index)
            summary_tsv_path = run_dir === nothing ? nothing : joinpath(run_dir, "summary.tsv")
            if resume && run_dir !== nothing && isfile(summary_tsv_path)
                stored = _read_lenia_experiment_run(summary_tsv_path)
                if _lenia_experiment_resume_matches(
                    stored,
                    preset,
                    tau_step,
                    feature_count,
                    acceptance_config,
                    initial_condition,
                    certificate_check !== nothing,
                ) && isempty(_lenia_experiment_report_entry(merge(stored, (
                    output_dir=run_dir,
                ))).missing_artifacts)
                    push!(experiments, nothing)
                    push!(entries, merge(stored, (
                        index=run_index,
                        resumed=true,
                        output_dir=run_dir,
                        artifact_path=joinpath(run_dir, "artifact.json"),
                        summary_path=joinpath(run_dir, "summary.json"),
                        summary_tsv_path=summary_tsv_path,
                        certificate_path=stored.certified ?
                            joinpath(run_dir, "certificate.json") : nothing,
                    )))
                    continue
                end
            end

            series = compare_lenia_parameter_grid(
                [tau_step],
                [feature_count];
                shape=preset.shape,
                action_count=preset.action_count,
                kernel_size=preset.kernel_size,
                acceptance_config=acceptance_config,
                certificate_check=certificate_check,
                initial_condition=initial_condition,
                kwargs...,
            )
            condition = first(series.summary)
            reproducibility = condition.reproducibility
            accepted = lenia_parameter_grid_certificate(series).ok
            run_summary = (
                tau_step=tau_step,
                feature_count=feature_count,
                shape_rows=preset.shape[1],
                shape_cols=preset.shape[2],
                action_count=preset.action_count,
                kernel_size=preset.kernel_size,
                seed=acceptance_config.seed,
                repeats=acceptance_config.repeats,
                relative_tolerance=acceptance_config.relative_tolerance,
                lambda_threshold=acceptance_config.lambda_threshold,
                eig_tol=acceptance_config.eig_tol,
                initial_mode=initial_condition.mode,
                initial_baseline=initial_condition.baseline,
                initial_amplitude=initial_condition.amplitude,
                initial_width=initial_condition.width,
                system_fingerprint=first(series.results).result.artifact.system_fingerprint,
                artifact_sha256=bytes2hex(SHA.sha256(series.artifact_json)),
                certified=certificate_check !== nothing,
                accepted=accepted,
                dominant_eigenvalue=condition.dominant_eigenvalue,
                max_relative_deviation=reproducibility.max_relative_deviation,
                status=condition.status,
            )
            certificate_json = certificate_check === nothing ? nothing :
                certified_lenia_parameter_grid_json(series, certificate_check)
            paths = run_dir === nothing ? NamedTuple() :
                _write_lenia_experiment_run(
                    run_dir,
                    series.artifact_json,
                    run_summary;
                    certificate_json=certificate_json,
                )
            push!(experiments, series)
            push!(entries, merge(run_summary, (
                index=run_index,
                resumed=false,
                output_dir=run_dir,
                artifact_path=hasproperty(paths, :artifact_path) ? paths.artifact_path : nothing,
                summary_path=hasproperty(paths, :summary_path) ? paths.summary_path : nothing,
                summary_tsv_path=hasproperty(paths, :summary_tsv_path) ?
                    paths.summary_tsv_path : nothing,
                certificate_path=hasproperty(paths, :certificate_path) ?
                    paths.certificate_path : nothing,
            )))
        end
    end
    summary = (
        kind=:LeniaExperimentSweep,
        preset=preset.name,
        description=preset.description,
        run_count=length(entries),
        total_condition_count=plan.total_condition_count,
        selected_run_indices=plan.selected_run_indices,
        selected_architecture_runs=plan.selected_architecture_runs,
        accepted_count=count(entry -> entry.accepted, entries),
        resumed_count=count(entry -> entry.resumed, entries),
        tau_steps=copy(preset.tau_steps),
        feature_counts=copy(preset.feature_counts),
        entries=entries,
    )
    artifact_paths = output_dir === nothing ? NamedTuple() :
        _write_lenia_experiment_sweep(output_dir, summary)
    LeniaExperimentSweepResult(experiments, summary, artifact_paths)
end
