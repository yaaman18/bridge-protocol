struct TRMNeuralTrainingExperimentResult{R,D,T,O,S,P}
    rollout::R
    dataset::D
    training_run::T
    optimizer_state::O
    summary::S
    artifact_paths::P
end

struct TRMNeuralTrainingExperimentSweepResult{E,S,P}
    experiments::E
    summary::S
    artifact_paths::P
end

struct TRMNeuralExperimentPreset{S,H,L,C,E}
    name::Symbol
    system::Symbol
    rollout_steps::Int
    hidden_dims::H
    learning_rates::L
    checkpoint_counts::C
    epochs_per_checkpoint_values::E
    certified::Bool
    description::S
end

function trm_neural_experiment_preset_catalog()
    (
        smoke=TRMNeuralExperimentPreset(
            :smoke,
            :toy,
            2,
            [4],
            [0.05],
            [2],
            [5],
            false,
            "Fast toy-system smoke preset for CI and local checks.",
        ),
        short=TRMNeuralExperimentPreset(
            :short,
            :toy,
            4,
            [4, 8],
            [0.02, 0.05],
            [3],
            [10],
            false,
            "Small toy-system sweep for backend regression runs.",
        ),
        long=TRMNeuralExperimentPreset(
            :long,
            :lenia,
            8,
            [8, 16],
            [0.01, 0.02, 0.05],
            [5],
            [20],
            true,
            "Longer Lenia-backed sweep with certified artifacts enabled.",
        ),
    )
end

function trm_neural_experiment_preset(name::Symbol)
    catalog = trm_neural_experiment_preset_catalog()
    hasproperty(catalog, name) ||
        throw(ArgumentError("unknown TRM neural experiment preset: $name"))
    getproperty(catalog, name)
end

function _read_key_value_file(path::AbstractString)
    values = Dict{String,String}()
    for line in eachline(path)
        stripped = strip(line)
        (isempty(stripped) || startswith(stripped, "#")) && continue
        parts = occursin('\t', stripped) ?
            split(stripped, '\t'; limit=2) :
            split(stripped, '='; limit=2)
        length(parts) == 2 || throw(ArgumentError("invalid preset line: $line"))
        values[strip(parts[1])] = strip(parts[2])
    end
    values
end

function _preset_value(values::Dict{String,String}, key::AbstractString, default)
    haskey(values, key) ? values[key] : default
end

function _parse_preset_int(value, key::AbstractString)
    parsed = parse(Int, string(value))
    parsed > 0 || throw(ArgumentError("$key must be positive"))
    parsed
end

function _parse_preset_int_list(value, key::AbstractString)
    parsed = [_parse_preset_int(strip(part), key) for part in split(string(value), ",")]
    isempty(parsed) && throw(ArgumentError("$key must be non-empty"))
    parsed
end

function _parse_preset_float_list(value, key::AbstractString)
    parsed = [parse(Float64, strip(part)) for part in split(string(value), ",")]
    !isempty(parsed) && all(item -> item > 0, parsed) ||
        throw(ArgumentError("$key must contain positive values"))
    parsed
end

function _parse_preset_bool(value, key::AbstractString)
    lowered = lowercase(string(value))
    lowered in ("true", "yes", "1") && return true
    lowered in ("false", "no", "0") && return false
    throw(ArgumentError("$key must be true or false"))
end

function _preset_file_name(path::AbstractString)
    stem = splitext(basename(path))[1]
    isempty(stem) && return :external
    Symbol(stem)
end

function read_trm_neural_experiment_preset(path::AbstractString)
    values = _read_key_value_file(path)
    base = trm_neural_experiment_preset(:smoke)
    name_value = _preset_value(values, "name", _preset_value(values, "preset", _preset_file_name(path)))
    system = Symbol(_preset_value(values, "system", base.system))
    system in (:toy, :lenia) || throw(ArgumentError("system must be toy or lenia"))
    rollout_steps = _parse_preset_int(
        _preset_value(values, "rollout_steps", base.rollout_steps),
        "rollout_steps",
    )
    hidden_dims = _parse_preset_int_list(
        _preset_value(values, "hidden_dims", join(base.hidden_dims, ",")),
        "hidden_dims",
    )
    learning_rates = _parse_preset_float_list(
        _preset_value(values, "learning_rates", join(base.learning_rates, ",")),
        "learning_rates",
    )
    checkpoint_counts = _parse_preset_int_list(
        _preset_value(values, "checkpoint_counts", join(base.checkpoint_counts, ",")),
        "checkpoint_counts",
    )
    epochs_value = _preset_value(
        values,
        "epochs_per_checkpoint_values",
        _preset_value(
            values,
            "epochs_per_checkpoint",
            join(base.epochs_per_checkpoint_values, ","),
        ),
    )
    epochs_per_checkpoint_values = _parse_preset_int_list(
        epochs_value,
        "epochs_per_checkpoint_values",
    )
    certified = _parse_preset_bool(
        _preset_value(values, "certified", base.certified),
        "certified",
    )
    description = String(_preset_value(
        values,
        "description",
        "External TRM neural experiment preset loaded from " * String(path),
    ))
    TRMNeuralExperimentPreset(
        Symbol(name_value),
        system,
        rollout_steps,
        hidden_dims,
        learning_rates,
        checkpoint_counts,
        epochs_per_checkpoint_values,
        certified,
        description,
    )
end

function trm_neural_experiment_preset_certificate(preset::TRMNeuralExperimentPreset)
    hidden_ok = !isempty(preset.hidden_dims) && all(value -> value > 0, preset.hidden_dims)
    learning_ok = !isempty(preset.learning_rates) &&
        all(value -> value > 0 && isfinite(value), preset.learning_rates)
    checkpoint_ok = !isempty(preset.checkpoint_counts) &&
        all(value -> value > 0, preset.checkpoint_counts)
    epoch_ok = !isempty(preset.epochs_per_checkpoint_values) &&
        all(value -> value > 0, preset.epochs_per_checkpoint_values)
    ok =
        preset.system in (:toy, :lenia) &&
        preset.rollout_steps > 0 &&
        hidden_ok &&
        learning_ok &&
        checkpoint_ok &&
        epoch_ok &&
        !isempty(string(preset.description))
    (
        kind=:TRMNeuralExperimentPreset,
        ok=ok,
        lean_contracts=String[],
        julia_checkers=[
            :trm_neural_experiment_preset_certificate,
            :read_trm_neural_experiment_preset,
        ],
        numeric_assumptions=(
            rollout_steps=preset.rollout_steps,
            hidden_dims=preset.hidden_dims,
            learning_rates=preset.learning_rates,
            checkpoint_counts=preset.checkpoint_counts,
            epochs_per_checkpoint_values=preset.epochs_per_checkpoint_values,
        ),
        name=preset.name,
        system=preset.system,
        certified=preset.certified,
        hidden_dim_count=length(preset.hidden_dims),
        learning_rate_count=length(preset.learning_rates),
        checkpoint_count_count=length(preset.checkpoint_counts),
        epochs_per_checkpoint_count=length(preset.epochs_per_checkpoint_values),
    )
end

function certified_trm_neural_experiment_preset(
    preset::TRMNeuralExperimentPreset,
    check::CertifiedArtifactCheck,
)
    instance_certificate = trm_neural_experiment_preset_certificate(preset)
    instance_certificate.ok ||
        throw(ArgumentError("cannot certify an invalid TRM neural experiment preset"))
    certified_artifact_envelope(instance_certificate, check)
end

certified_trm_neural_experiment_preset_json(
    preset::TRMNeuralExperimentPreset,
    check::CertifiedArtifactCheck,
) = _json_value(certified_trm_neural_experiment_preset(preset, check))

function write_certified_trm_neural_experiment_preset(
    path::AbstractString,
    preset::TRMNeuralExperimentPreset,
    check::CertifiedArtifactCheck,
)
    open(path, "w") do io
        write(io, certified_trm_neural_experiment_preset_json(preset, check))
        write(io, "\n")
    end
    path
end

function _trm_neural_experiment_summary(
    rollout::TRMClosedRolloutResult,
    dataset::TRMRolloutDataset,
    training_run::TRMTrainingRunResult,
    optimizer_state::TRMNeuralOptimizerState;
    output_dir::Union{AbstractString,Nothing}=nothing,
    certified::Bool=false,
)
    rollout_summary = summarize_trm_closed_rollout(rollout)
    (
        kind=:TRMNeuralTrainingExperiment,
        certified=certified,
        output_dir=output_dir === nothing ? nothing : String(output_dir),
        rollout_steps=length(rollout.steps),
        sample_count=length(dataset.samples),
        checkpoint_count=optimizer_state.summary.checkpoint_count,
        epochs_per_checkpoint=training_run.summary.epochs_per_checkpoint,
        cumulative_epochs=optimizer_state.summary.cumulative_epochs,
        hidden_dim=optimizer_state.summary.hidden_dim,
        activation=optimizer_state.summary.activation,
        learning_rate=optimizer_state.summary.learning_rate,
        accepted=training_run.summary.accepted,
        baseline_loss=training_run.summary.baseline_loss,
        final_loss=optimizer_state.summary.final_loss,
        improvement=training_run.summary.baseline_loss - optimizer_state.summary.final_loss,
        optimizer_final_loss=optimizer_state.summary.final_loss,
        world_nontrivial_count=count(identity, rollout_summary.world_nontrivial),
        classifications=rollout_summary.classifications,
        final_action=rollout.final_action,
    )
end

function _write_trm_neural_experiment_output(
    output_dir::AbstractString,
    rollout::TRMClosedRolloutResult,
    dataset::TRMRolloutDataset,
    training_run::TRMTrainingRunResult,
    optimizer_state::TRMNeuralOptimizerState,
    summary,
    certificate_check::Union{CertifiedArtifactCheck,Nothing},
)
    mkpath(output_dir)
    rollout_summary_path = joinpath(output_dir, "rollout-summary.json")
    optimizer_path = joinpath(output_dir, "optimizer.json")
    optimizer_state_tsv_path = joinpath(output_dir, "optimizer-state.tsv")
    summary_path = joinpath(output_dir, "summary.json")
    run_summary_tsv_path = joinpath(output_dir, "run-summary.tsv")
    dataset_certificate_path = certificate_check === nothing ? nothing :
        joinpath(output_dir, "dataset.certified.json")
    training_run_certificate_path = certificate_check === nothing ? nothing :
        joinpath(output_dir, "training-run.certified.json")
    optimizer_certificate_path = certificate_check === nothing ? nothing :
        joinpath(output_dir, "optimizer.certified.json")
    optimizer_checkpoint_certificate_path = certificate_check === nothing ? nothing :
        joinpath(output_dir, "optimizer-checkpoint.certified.json")

    open(rollout_summary_path, "w") do io
        write(io, _json_value(summarize_trm_closed_rollout(rollout)))
        write(io, "\n")
    end
    write_trm_neural_optimizer_state(optimizer_path, optimizer_state)
    write_trm_neural_optimizer_state_tsv(optimizer_state_tsv_path, optimizer_state)

    if certificate_check !== nothing
        open(dataset_certificate_path, "w") do io
            write(io, certified_trm_rollout_dataset_json(dataset, certificate_check))
            write(io, "\n")
        end
        open(training_run_certificate_path, "w") do io
            write(io, certified_trm_neural_training_run_json(training_run, certificate_check))
            write(io, "\n")
        end
        write_certified_trm_neural_optimizer_state(
            optimizer_certificate_path,
            optimizer_state,
            certificate_check,
        )
        write_certified_trm_neural_optimizer_checkpoint(
            optimizer_checkpoint_certificate_path,
            optimizer_state_tsv_path,
            certificate_check,
        )
    end

    paths = (
        output_dir=String(output_dir),
        summary_path=summary_path,
        run_summary_tsv_path=run_summary_tsv_path,
        rollout_summary_path=rollout_summary_path,
        optimizer_path=optimizer_path,
        optimizer_state_tsv_path=optimizer_state_tsv_path,
        dataset_certificate_path=dataset_certificate_path,
        training_run_certificate_path=training_run_certificate_path,
        optimizer_certificate_path=optimizer_certificate_path,
        optimizer_checkpoint_certificate_path=optimizer_checkpoint_certificate_path,
    )
    enriched_summary = merge(summary, (artifact_paths=paths,))
    open(summary_path, "w") do io
        write(io, _json_value(enriched_summary))
        write(io, "\n")
    end
    _write_trm_neural_run_summary_tsv(run_summary_tsv_path, summary)
    paths
end

function run_trm_neural_training_experiment(
    adapter::SigmaSystemAdapter,
    initial_action::AbstractVector,
    dc_result::DCResult;
    consumer::TRMConsumer=TRMConsumer(default_trm_program()),
    rollout_steps::Integer=4,
    normalize_pipeline::Bool=true,
    pipeline_weights::Union{AbstractVector,Nothing}=nothing,
    direction::Union{AbstractVector,Nothing}=nothing,
    target::Real=1.0,
    eig_tol::Real=1e-6,
    fixed_tol::Real=1e-6,
    reachable_directions=nothing,
    action_index::Union{Integer,Nothing}=nothing,
    fm1_with_action::Union{Bool,Nothing}=nothing,
    fm1_without_action::Union{Bool,Nothing}=nothing,
    interoceptive_signal=nothing,
    hidden_dim::Integer=8,
    activation::Symbol=:tanh,
    learning_rate::Real=1e-2,
    checkpoint_count::Integer=3,
    epochs_per_checkpoint::Integer=10,
    loss_weights::TRMLossWeights=TRMLossWeights(),
    improvement_tol::Real=1e-10,
    output_dir::Union{AbstractString,Nothing}=nothing,
    certificate_check::Union{CertifiedArtifactCheck,Nothing}=nothing,
    continue_from_optimizer::Bool=false,
)
    rollout_steps >= 1 || throw(ArgumentError("rollout_steps must be at least 1"))
    rollout = run_trm_closed_rollout(
        adapter,
        initial_action,
        dc_result;
        consumer=consumer,
        steps=rollout_steps,
        normalize_pipeline=normalize_pipeline,
        weights=pipeline_weights,
        direction=direction,
        target=target,
        eig_tol=eig_tol,
        fixed_tol=fixed_tol,
        reachable_directions=reachable_directions,
        action_index=action_index,
        fm1_with_action=fm1_with_action,
        fm1_without_action=fm1_without_action,
        interoceptive_signal=interoceptive_signal,
    )
    dataset = trm_rollout_dataset(rollout)
    restored_state = continue_from_optimizer && output_dir !== nothing ?
        _matching_trm_optimizer_state(
            joinpath(output_dir, "optimizer-state.tsv"),
            dataset,
            hidden_dim,
            activation,
            learning_rate,
            checkpoint_count,
        ) : nothing
    completed_checkpoints = restored_state === nothing ? 0 :
        restored_state.summary.checkpoint_count
    remaining_checkpoints = Int(checkpoint_count) - completed_checkpoints
    remaining_checkpoints >= 1 ||
        throw(ArgumentError("continued TRM neural experiment already satisfies requested checkpoint_count"))
    training_run = trm_neural_training_run(
        dataset;
        hidden_dim=hidden_dim,
        activation=activation,
        learning_rate=learning_rate,
        checkpoint_count=remaining_checkpoints,
        epochs_per_checkpoint=epochs_per_checkpoint,
        weights=loss_weights,
        improvement_tol=improvement_tol,
        initial_model=restored_state === nothing ? nothing : restored_state.model,
    )
    optimizer_state = restored_state === nothing ?
        trm_neural_optimizer_state(training_run) :
        _combine_trm_optimizer_states(
            restored_state,
            trm_neural_optimizer_state(training_run),
            dataset,
            training_run;
            requested_checkpoint_count=checkpoint_count,
        )
    summary = _trm_neural_experiment_summary(
        rollout,
        dataset,
        training_run,
        optimizer_state;
        output_dir=output_dir,
        certified=certificate_check !== nothing,
    )
    artifact_paths = output_dir === nothing ? NamedTuple() :
        _write_trm_neural_experiment_output(
            output_dir,
            rollout,
            dataset,
            training_run,
            optimizer_state,
            summary,
            certificate_check,
        )
    TRMNeuralTrainingExperimentResult(
        rollout,
        dataset,
        training_run,
        optimizer_state,
        summary,
        artifact_paths,
    )
end

function _matching_trm_optimizer_state(
    path::AbstractString,
    dataset::TRMRolloutDataset,
    hidden_dim::Integer,
    activation::Symbol,
    learning_rate::Real,
    requested_checkpoint_count::Integer,
)
    isfile(path) || return nothing
    state = read_trm_neural_optimizer_state_tsv(path)
    feature_dim = length(trm_learning_feature_vector(first(dataset.samples).observation))
    action_dim = length(first(dataset.samples).target_action)
    state.summary.hidden_dim == Int(hidden_dim) || return nothing
    state.summary.activation == activation || return nothing
    state.summary.learning_rate == Float64(learning_rate) || return nothing
    state.summary.action_dim == action_dim || return nothing
    state.summary.sample_count == length(dataset.samples) || return nothing
    size(state.model.input_weights) == (Int(hidden_dim), feature_dim) || return nothing
    size(state.model.output_weights) == (action_dim, Int(hidden_dim)) || return nothing
    0 < state.summary.checkpoint_count < Int(requested_checkpoint_count) || return nothing
    state
end

function _combine_trm_optimizer_states(
    restored::TRMNeuralOptimizerState,
    continuation::TRMNeuralOptimizerState,
    dataset::TRMRolloutDataset,
    training_run::TRMTrainingRunResult;
    requested_checkpoint_count::Integer,
)
    loss_trace = vcat(restored.loss_trace, continuation.loss_trace)
    epoch_trace = vcat(restored.epoch_trace, continuation.epoch_trace)
    summary = (
        checkpoint_count=length(loss_trace),
        activation=continuation.summary.activation,
        learning_rate=continuation.summary.learning_rate,
        cumulative_epochs=last(epoch_trace),
        final_loss=last(loss_trace),
        hidden_dim=continuation.summary.hidden_dim,
        action_dim=continuation.summary.action_dim,
        sample_count=length(dataset.samples),
    )
    summary.checkpoint_count == Int(requested_checkpoint_count) ||
        throw(ArgumentError("combined checkpoint count does not match requested checkpoint_count"))
    TRMNeuralOptimizerState(training_run.final_model, loss_trace, epoch_trace, summary)
end

function _check_positive_collection(values, name::AbstractString)
    collected = collect(values)
    !isempty(collected) || throw(ArgumentError("$name must contain at least one value"))
    all(value -> value > 0, collected) ||
        throw(ArgumentError("$name values must be positive"))
    collected
end

function _trm_sweep_run_dir(output_dir::AbstractString, index::Integer)
    joinpath(output_dir, "run-" * lpad(string(index), 3, '0'))
end

function _write_trm_neural_sweep_summary(
    output_dir::AbstractString,
    summary;
    certificate_check::Union{CertifiedArtifactCheck,Nothing}=nothing,
)
    mkpath(output_dir)
    summary_path = joinpath(output_dir, "summary.json")
    report_path = joinpath(output_dir, "report.json")
    certificate_graph_path = joinpath(output_dir, "certificate-graph.json")
    report_certificate_path = certificate_check === nothing ? nothing :
        joinpath(output_dir, "report.certified.json")
    open(summary_path, "w") do io
        write(io, _json_value(summary))
        write(io, "\n")
    end
    report = trm_neural_experiment_sweep_report(summary; output_dir=output_dir)
    open(report_path, "w") do io
        write(io, _json_value(report))
        write(io, "\n")
    end
    if certificate_check !== nothing
        write_certified_trm_neural_experiment_sweep_report(
            report_certificate_path,
            report,
            certificate_check,
        )
    end
    certificate_graph = trm_neural_experiment_sweep_certificate_graph(
        report;
        report_certificate_path=report_certificate_path,
    )
    open(certificate_graph_path, "w") do io
        write(io, _json_value(certificate_graph))
        write(io, "\n")
    end
    (
        output_dir=String(output_dir),
        summary_path=summary_path,
        report_path=report_path,
        certificate_graph_path=certificate_graph_path,
        report_certificate_path=report_certificate_path,
    )
end

function _nt_property(value, key::Symbol, default=nothing)
    hasproperty(value, key) ? getproperty(value, key) : default
end

function _trm_run_artifact_paths(output_dir)
    output_dir === nothing && return NamedTuple()
    (
        summary_path=joinpath(output_dir, "summary.json"),
        run_summary_tsv_path=joinpath(output_dir, "run-summary.tsv"),
        rollout_summary_path=joinpath(output_dir, "rollout-summary.json"),
        optimizer_path=joinpath(output_dir, "optimizer.json"),
        optimizer_state_tsv_path=joinpath(output_dir, "optimizer-state.tsv"),
    )
end

function _trm_run_certificate_paths(output_dir)
    output_dir === nothing && return NamedTuple()
    (
        dataset_certificate_path=joinpath(output_dir, "dataset.certified.json"),
        training_run_certificate_path=joinpath(output_dir, "training-run.certified.json"),
        optimizer_certificate_path=joinpath(output_dir, "optimizer.certified.json"),
        optimizer_checkpoint_certificate_path=joinpath(output_dir, "optimizer-checkpoint.certified.json"),
    )
end

function _trm_missing_run_artifacts(entry)
    output_dir = _nt_property(entry, :output_dir, nothing)
    output_dir === nothing && return String[]
    paths = _trm_run_artifact_paths(output_dir)
    missing = String[]
    for key in keys(paths)
        path = getproperty(paths, key)
        isfile(path) || push!(missing, String(key))
    end
    missing
end

function _trm_sweep_report_entry(entry)
    missing = _trm_missing_run_artifacts(entry)
    merge(entry, (
        artifact_complete=isempty(missing),
        missing_artifacts=missing,
    ))
end

function _trm_sweep_best_entry(entries)
    completed = filter(entry -> _nt_property(entry, :final_loss, nothing) !== nothing, entries)
    isempty(completed) && return nothing
    completed[argmin([entry.final_loss for entry in completed])]
end

function trm_neural_experiment_sweep_report(summary::NamedTuple; output_dir=nothing)
    entries = [_trm_sweep_report_entry(entry) for entry in summary.entries]
    best_entry = _trm_sweep_best_entry(entries)
    missing_artifact_count = sum(length(entry.missing_artifacts) for entry in entries)
    (
        kind=:TRMNeuralTrainingExperimentSweepReport,
        output_dir=output_dir === nothing ? _nt_property(summary, :output_dir, nothing) : String(output_dir),
        run_count=length(entries),
        completed_run_count=count(entry -> _nt_property(entry, :final_loss, nothing) !== nothing, entries),
        accepted_count=count(entry -> _nt_property(entry, :accepted, false), entries),
        resumed_count=_nt_property(summary, :resumed_count, 0),
        best_index=best_entry === nothing ? nothing : best_entry.index,
        best_final_loss=best_entry === nothing ? nothing : best_entry.final_loss,
        artifact_complete_count=count(entry -> entry.artifact_complete, entries),
        missing_artifact_count=missing_artifact_count,
        entries=entries,
    )
end

trm_neural_experiment_sweep_report(
    sweep::TRMNeuralTrainingExperimentSweepResult,
) = trm_neural_experiment_sweep_report(
    sweep.summary;
    output_dir=_nt_property(sweep.artifact_paths, :output_dir, nothing),
)

function _trm_run_index_from_dir(path::AbstractString)
    name = basename(path)
    m = match(r"^run-(\d+)$", name)
    m === nothing && return nothing
    parse(Int, m.captures[1])
end

function trm_neural_experiment_sweep_report(output_dir::AbstractString)
    isdir(output_dir) || throw(ArgumentError("TRM sweep output_dir does not exist: $output_dir"))
    entries = NamedTuple[]
    for name in sort(readdir(output_dir))
        run_dir = joinpath(output_dir, name)
        isdir(run_dir) || continue
        index = _trm_run_index_from_dir(run_dir)
        index === nothing && continue
        run_summary_tsv_path = joinpath(run_dir, "run-summary.tsv")
        if isfile(run_summary_tsv_path)
            run_summary = _read_trm_neural_run_summary_tsv(run_summary_tsv_path)
            push!(entries, _trm_sweep_report_entry((
                index=index,
                hidden_dim=run_summary.hidden_dim,
                learning_rate=run_summary.learning_rate,
                checkpoint_count=run_summary.checkpoint_count,
                epochs_per_checkpoint=run_summary.epochs_per_checkpoint,
                accepted=run_summary.accepted,
                final_loss=run_summary.final_loss,
                improvement=run_summary.improvement,
                output_dir=run_dir,
                summary_path=joinpath(run_dir, "summary.json"),
                run_summary_tsv_path=run_summary_tsv_path,
                resumed=false,
                completed=true,
            )))
        else
            push!(entries, _trm_sweep_report_entry((
                index=index,
                hidden_dim=nothing,
                learning_rate=nothing,
                checkpoint_count=nothing,
                epochs_per_checkpoint=nothing,
                accepted=false,
                final_loss=nothing,
                improvement=nothing,
                output_dir=run_dir,
                summary_path=joinpath(run_dir, "summary.json"),
                run_summary_tsv_path=run_summary_tsv_path,
                resumed=false,
                completed=false,
            )))
        end
    end
    best_entry = _trm_sweep_best_entry(entries)
    (
        kind=:TRMNeuralTrainingExperimentSweepReport,
        output_dir=String(output_dir),
        run_count=length(entries),
        completed_run_count=count(entry -> _nt_property(entry, :completed, true), entries),
        accepted_count=count(entry -> _nt_property(entry, :accepted, false), entries),
        resumed_count=nothing,
        best_index=best_entry === nothing ? nothing : best_entry.index,
        best_final_loss=best_entry === nothing ? nothing : best_entry.final_loss,
        artifact_complete_count=count(entry -> entry.artifact_complete, entries),
        missing_artifact_count=sum(length(entry.missing_artifacts) for entry in entries),
        entries=entries,
    )
end

trm_neural_experiment_sweep_report_json(sweep::TRMNeuralTrainingExperimentSweepResult) =
    _json_value(trm_neural_experiment_sweep_report(sweep))

trm_neural_experiment_sweep_report_json(output_dir::AbstractString) =
    _json_value(trm_neural_experiment_sweep_report(output_dir))

function write_trm_neural_experiment_sweep_report(
    path::AbstractString,
    sweep::TRMNeuralTrainingExperimentSweepResult,
)
    open(path, "w") do io
        write(io, trm_neural_experiment_sweep_report_json(sweep))
        write(io, "\n")
    end
    path
end

function write_trm_neural_experiment_sweep_report(
    path::AbstractString,
    output_dir::AbstractString,
)
    open(path, "w") do io
        write(io, trm_neural_experiment_sweep_report_json(output_dir))
        write(io, "\n")
    end
    path
end

function _trm_report_best_loss_ok(report)
    completed = filter(
        entry -> _nt_property(entry, :final_loss, nothing) !== nothing,
        report.entries,
    )
    isempty(completed) && return report.best_index === nothing && report.best_final_loss === nothing
    best = completed[argmin([entry.final_loss for entry in completed])]
    report.best_index == best.index && report.best_final_loss == best.final_loss
end

function trm_neural_experiment_sweep_report_certificate(report::NamedTuple)
    report.kind == :TRMNeuralTrainingExperimentSweepReport ||
        throw(ArgumentError("not a TRM neural experiment sweep report"))
    run_count_ok = report.run_count == length(report.entries)
    completed_count = count(
        entry -> _nt_property(entry, :final_loss, nothing) !== nothing,
        report.entries,
    )
    completed_count_ok = report.completed_run_count == completed_count
    accepted_count_ok = report.accepted_count ==
        count(entry -> _nt_property(entry, :accepted, false), report.entries)
    artifact_complete_count_ok = report.artifact_complete_count ==
        count(entry -> _nt_property(entry, :artifact_complete, false), report.entries)
    missing_count = sum(length(_nt_property(entry, :missing_artifacts, String[])) for entry in report.entries)
    missing_count_ok = report.missing_artifact_count == missing_count
    entry_artifact_flags_ok = all(
        entry -> _nt_property(entry, :artifact_complete, false) ==
            isempty(_nt_property(entry, :missing_artifacts, String[])),
        report.entries,
    )
    best_loss_ok = _trm_report_best_loss_ok(report)
    ok =
        run_count_ok &&
        completed_count_ok &&
        accepted_count_ok &&
        artifact_complete_count_ok &&
        missing_count_ok &&
        entry_artifact_flags_ok &&
        best_loss_ok
    (
        kind=:TRMNeuralTrainingExperimentSweepReport,
        ok=ok,
        lean_contracts=String[],
        julia_checkers=[
            :trm_neural_experiment_sweep_report,
            :trm_neural_experiment_sweep_report_certificate,
        ],
        numeric_assumptions=(
            run_count=report.run_count,
            completed_run_count=report.completed_run_count,
            accepted_count=report.accepted_count,
            best_final_loss=report.best_final_loss,
            missing_artifact_count=report.missing_artifact_count,
        ),
        run_count=report.run_count,
        completed_run_count=report.completed_run_count,
        accepted_count=report.accepted_count,
        resumed_count=report.resumed_count,
        best_index=report.best_index,
        best_final_loss=report.best_final_loss,
        artifact_complete_count=report.artifact_complete_count,
        missing_artifact_count=report.missing_artifact_count,
        run_count_ok=run_count_ok,
        completed_count_ok=completed_count_ok,
        accepted_count_ok=accepted_count_ok,
        artifact_complete_count_ok=artifact_complete_count_ok,
        missing_count_ok=missing_count_ok,
        entry_artifact_flags_ok=entry_artifact_flags_ok,
        best_loss_ok=best_loss_ok,
    )
end

function certified_trm_neural_experiment_sweep_report(
    report::NamedTuple,
    check::CertifiedArtifactCheck,
)
    instance_certificate = trm_neural_experiment_sweep_report_certificate(report)
    instance_certificate.ok ||
        throw(ArgumentError("cannot certify an invalid TRM neural experiment sweep report"))
    certified_artifact_envelope(instance_certificate, check)
end

certified_trm_neural_experiment_sweep_report_json(
    report::NamedTuple,
    check::CertifiedArtifactCheck,
) = _json_value(certified_trm_neural_experiment_sweep_report(report, check))

function write_certified_trm_neural_experiment_sweep_report(
    path::AbstractString,
    report::NamedTuple,
    check::CertifiedArtifactCheck,
)
    open(path, "w") do io
        write(io, certified_trm_neural_experiment_sweep_report_json(report, check))
        write(io, "\n")
    end
    path
end

function _trm_report_certificate_entry(entry)
    output_dir = _nt_property(entry, :output_dir, nothing)
    output_dir === nothing && return merge(entry, (
        certificate_paths=NamedTuple(),
        certificate_complete=false,
        missing_certificates=String[],
    ))
    paths = _trm_run_certificate_paths(output_dir)
    missing = String[]
    for key in keys(paths)
        path = getproperty(paths, key)
        isfile(path) || push!(missing, String(key))
    end
    merge(entry, (
        certificate_paths=paths,
        certificate_complete=isempty(missing),
        missing_certificates=missing,
    ))
end

function trm_neural_experiment_sweep_certificate_graph(
    report::NamedTuple;
    report_certificate_path=nothing,
)
    report.kind == :TRMNeuralTrainingExperimentSweepReport ||
        throw(ArgumentError("not a TRM neural experiment sweep report"))
    entries = [_trm_report_certificate_entry(entry) for entry in report.entries]
    report_certificate_exists =
        report_certificate_path !== nothing && isfile(report_certificate_path)
    run_edges = [
        (
            from=:TRMNeuralTrainingExperimentSweepReport,
            to="run-$(lpad(string(entry.index), 3, '0'))",
            relation=:summarizes_run,
        )
        for entry in entries
    ]
    certificate_edges = NamedTuple[]
    for entry in entries
        run_node = "run-$(lpad(string(entry.index), 3, '0'))"
        for key in keys(entry.certificate_paths)
            path = getproperty(entry.certificate_paths, key)
            if isfile(path)
                push!(certificate_edges, (
                    from=run_node,
                    to=String(key),
                    relation=:has_certificate_artifact,
                    path=path,
                ))
            end
        end
    end
    if report_certificate_exists
        push!(certificate_edges, (
            from=:TRMNeuralTrainingExperimentSweepReport,
            to=:report_certificate_path,
            relation=:has_certificate_artifact,
            path=String(report_certificate_path),
        ))
    end
    (
        kind=:TRMNeuralTrainingExperimentSweepCertificateGraph,
        report_kind=report.kind,
        output_dir=report.output_dir,
        run_count=length(entries),
        report_certificate_path=report_certificate_path,
        report_certificate_exists=report_certificate_exists,
        certificate_complete_count=count(entry -> entry.certificate_complete, entries),
        missing_certificate_count=sum(length(entry.missing_certificates) for entry in entries),
        entries=entries,
        edges=vcat(run_edges, certificate_edges),
    )
end

function trm_neural_experiment_sweep_certificate_graph(
    sweep::TRMNeuralTrainingExperimentSweepResult,
)
    report = trm_neural_experiment_sweep_report(sweep)
    trm_neural_experiment_sweep_certificate_graph(
        report;
        report_certificate_path=_nt_property(
            sweep.artifact_paths,
            :report_certificate_path,
            nothing,
        ),
    )
end

function trm_neural_experiment_sweep_certificate_graph(output_dir::AbstractString)
    report = trm_neural_experiment_sweep_report(output_dir)
    report_certificate_path = joinpath(output_dir, "report.certified.json")
    trm_neural_experiment_sweep_certificate_graph(
        report;
        report_certificate_path=isfile(report_certificate_path) ? report_certificate_path : nothing,
    )
end

trm_neural_experiment_sweep_certificate_graph_json(
    sweep::TRMNeuralTrainingExperimentSweepResult,
) = _json_value(trm_neural_experiment_sweep_certificate_graph(sweep))

trm_neural_experiment_sweep_certificate_graph_json(output_dir::AbstractString) =
    _json_value(trm_neural_experiment_sweep_certificate_graph(output_dir))

function write_trm_neural_experiment_sweep_certificate_graph(
    path::AbstractString,
    sweep::TRMNeuralTrainingExperimentSweepResult,
)
    open(path, "w") do io
        write(io, trm_neural_experiment_sweep_certificate_graph_json(sweep))
        write(io, "\n")
    end
    path
end

function write_trm_neural_experiment_sweep_certificate_graph(
    path::AbstractString,
    output_dir::AbstractString,
)
    open(path, "w") do io
        write(io, trm_neural_experiment_sweep_certificate_graph_json(output_dir))
        write(io, "\n")
    end
    path
end

function _trm_expected_certificate_kind(certificate_key)
    certificate_key == :dataset_certificate_path && return :TRMRolloutDataset
    certificate_key == :training_run_certificate_path && return :TRMNeuralTrainingRun
    certificate_key == :optimizer_certificate_path && return :TRMNeuralOptimizerState
    certificate_key == :optimizer_checkpoint_certificate_path &&
        return :TRMNeuralOptimizerCheckpoint
    certificate_key == :report_certificate_path &&
        return :TRMNeuralTrainingExperimentSweepReport
    nothing
end

function trm_neural_experiment_sweep_certified_envelope_audit(graph::NamedTuple)
    graph.kind == :TRMNeuralTrainingExperimentSweepCertificateGraph ||
        throw(ArgumentError("not a TRM neural experiment sweep certificate graph"))
    audits = NamedTuple[]
    for edge in graph.edges
        _nt_property(edge, :relation, nothing) == :has_certificate_artifact || continue
        path = _nt_property(edge, :path, nothing)
        path === nothing && continue
        expected_kind = _trm_expected_certificate_kind(Symbol(_nt_property(edge, :to, "")))
        push!(audits, merge(
            certified_json_artifact_audit(path; expected_kind=expected_kind),
            (
                source=_nt_property(edge, :from, nothing),
                certificate_key=_nt_property(edge, :to, nothing),
            ),
        ))
    end
    (
        kind=:TRMNeuralTrainingExperimentSweepCertifiedEnvelopeAudit,
        graph_kind=graph.kind,
        output_dir=graph.output_dir,
        audit_count=length(audits),
        ok_count=count(audit -> audit.ok, audits),
        failed_count=count(audit -> !audit.ok, audits),
        ok=all(audit -> audit.ok, audits),
        audits=audits,
    )
end

function trm_neural_experiment_sweep_certified_envelope_audit(
    sweep::TRMNeuralTrainingExperimentSweepResult,
)
    trm_neural_experiment_sweep_certified_envelope_audit(
        trm_neural_experiment_sweep_certificate_graph(sweep),
    )
end

function trm_neural_experiment_sweep_certified_envelope_audit(
    output_dir::AbstractString,
)
    trm_neural_experiment_sweep_certified_envelope_audit(
        trm_neural_experiment_sweep_certificate_graph(output_dir),
    )
end

trm_neural_experiment_sweep_certified_envelope_audit_json(
    sweep::TRMNeuralTrainingExperimentSweepResult,
) = _json_value(trm_neural_experiment_sweep_certified_envelope_audit(sweep))

trm_neural_experiment_sweep_certified_envelope_audit_json(output_dir::AbstractString) =
    _json_value(trm_neural_experiment_sweep_certified_envelope_audit(output_dir))

function write_trm_neural_experiment_sweep_certified_envelope_audit(
    path::AbstractString,
    sweep::TRMNeuralTrainingExperimentSweepResult,
)
    open(path, "w") do io
        write(io, trm_neural_experiment_sweep_certified_envelope_audit_json(sweep))
        write(io, "\n")
    end
    path
end

function write_trm_neural_experiment_sweep_certified_envelope_audit(
    path::AbstractString,
    output_dir::AbstractString,
)
    open(path, "w") do io
        write(io, trm_neural_experiment_sweep_certified_envelope_audit_json(output_dir))
        write(io, "\n")
    end
    path
end

function _tsv_join(values)
    join(string.(values), ",")
end

function _tsv_parse_float_vector(value::AbstractString)
    isempty(value) && return Float64[]
    [parse(Float64, item) for item in split(value, ",")]
end

function _tsv_parse_int_vector(value::AbstractString)
    isempty(value) && return Int[]
    [parse(Int, item) for item in split(value, ",")]
end

function _tsv_parse_matrix(value::AbstractString, rows::Integer, cols::Integer)
    values = _tsv_parse_float_vector(value)
    length(values) == rows * cols ||
        throw(ArgumentError("matrix payload does not match declared shape"))
    reshape(values, Int(rows), Int(cols))
end

function write_trm_neural_optimizer_state_tsv(
    path::AbstractString,
    state::TRMNeuralOptimizerState,
)
    model = state.model
    model isa TRMNeuralActionModel ||
        throw(ArgumentError("optimizer state model must be TRMNeuralActionModel"))
    open(path, "w") do io
        println(io, "format\tERIEC_TRM_NEURAL_OPTIMIZER_STATE\t1")
        println(io, "activation\t", model.activation)
        println(io, "learning_rate\t", model.learning_rate)
        println(io, "epochs\t", model.epochs)
        println(io, "training_loss\t", model.training_loss)
        println(io, "input_shape\t", size(model.input_weights, 1), ",", size(model.input_weights, 2))
        println(io, "input_weights\t", _tsv_join(vec(model.input_weights)))
        println(io, "hidden_bias\t", _tsv_join(model.hidden_bias))
        println(io, "output_shape\t", size(model.output_weights, 1), ",", size(model.output_weights, 2))
        println(io, "output_weights\t", _tsv_join(vec(model.output_weights)))
        println(io, "output_bias\t", _tsv_join(model.output_bias))
        println(io, "loss_trace\t", _tsv_join(state.loss_trace))
        println(io, "epoch_trace\t", _tsv_join(state.epoch_trace))
        println(io, "summary_checkpoint_count\t", state.summary.checkpoint_count)
        println(io, "summary_cumulative_epochs\t", state.summary.cumulative_epochs)
        println(io, "summary_final_loss\t", state.summary.final_loss)
        println(io, "summary_activation\t", state.summary.activation)
        println(io, "summary_learning_rate\t", state.summary.learning_rate)
        println(io, "summary_hidden_dim\t", state.summary.hidden_dim)
        println(io, "summary_action_dim\t", state.summary.action_dim)
        println(io, "summary_sample_count\t", state.summary.sample_count)
    end
    path
end

function _read_keyed_tsv(path::AbstractString)
    values = Dict{String,String}()
    for line in eachline(path)
        isempty(strip(line)) && continue
        parts = split(line, '\t'; limit=2)
        length(parts) == 2 || throw(ArgumentError("invalid TSV line: $line"))
        values[parts[1]] = parts[2]
    end
    values
end

function _require_tsv_key(values::Dict{String,String}, key::AbstractString)
    haskey(values, key) || throw(ArgumentError("missing TSV key: $key"))
    values[key]
end

function _parse_tsv_shape(value::AbstractString)
    parts = split(value, ",")
    length(parts) == 2 || throw(ArgumentError("shape must contain two dimensions"))
    parse.(Int, parts)
end

function read_trm_neural_optimizer_state_tsv(path::AbstractString)
    values = _read_keyed_tsv(path)
    _require_tsv_key(values, "format") == "ERIEC_TRM_NEURAL_OPTIMIZER_STATE\t1" ||
        throw(ArgumentError("unsupported TRM neural optimizer state TSV format"))
    input_rows, input_cols = _parse_tsv_shape(_require_tsv_key(values, "input_shape"))
    output_rows, output_cols = _parse_tsv_shape(_require_tsv_key(values, "output_shape"))
    model = TRMNeuralActionModel(
        _tsv_parse_matrix(_require_tsv_key(values, "input_weights"), input_rows, input_cols),
        _tsv_parse_float_vector(_require_tsv_key(values, "hidden_bias")),
        _tsv_parse_matrix(_require_tsv_key(values, "output_weights"), output_rows, output_cols),
        _tsv_parse_float_vector(_require_tsv_key(values, "output_bias")),
        Symbol(_require_tsv_key(values, "activation")),
        parse(Float64, _require_tsv_key(values, "learning_rate")),
        parse(Int, _require_tsv_key(values, "epochs")),
        parse(Float64, _require_tsv_key(values, "training_loss")),
    )
    summary = (
        checkpoint_count=parse(Int, _require_tsv_key(values, "summary_checkpoint_count")),
        activation=Symbol(_require_tsv_key(values, "summary_activation")),
        learning_rate=parse(Float64, _require_tsv_key(values, "summary_learning_rate")),
        cumulative_epochs=parse(Int, _require_tsv_key(values, "summary_cumulative_epochs")),
        final_loss=parse(Float64, _require_tsv_key(values, "summary_final_loss")),
        hidden_dim=parse(Int, _require_tsv_key(values, "summary_hidden_dim")),
        action_dim=parse(Int, _require_tsv_key(values, "summary_action_dim")),
        sample_count=parse(Int, _require_tsv_key(values, "summary_sample_count")),
    )
    TRMNeuralOptimizerState(
        model,
        _tsv_parse_float_vector(_require_tsv_key(values, "loss_trace")),
        _tsv_parse_int_vector(_require_tsv_key(values, "epoch_trace")),
        summary,
    )
end

function _write_trm_neural_run_summary_tsv(path::AbstractString, summary)
    fields = (
        :kind,
        :accepted,
        :sample_count,
        :checkpoint_count,
        :epochs_per_checkpoint,
        :cumulative_epochs,
        :hidden_dim,
        :activation,
        :learning_rate,
        :baseline_loss,
        :final_loss,
        :improvement,
        :optimizer_final_loss,
        :world_nontrivial_count,
    )
    open(path, "w") do io
        for field in fields
            println(io, String(field), "\t", getproperty(summary, field))
        end
    end
    path
end

function _read_trm_neural_run_summary_tsv(path::AbstractString)
    values = Dict{String,String}()
    for line in eachline(path)
        isempty(strip(line)) && continue
        parts = split(line, '\t'; limit=2)
        length(parts) == 2 || throw(ArgumentError("invalid TRM run summary line: $line"))
        values[parts[1]] = parts[2]
    end
    required = [
        "accepted",
        "sample_count",
        "checkpoint_count",
        "epochs_per_checkpoint",
        "cumulative_epochs",
        "hidden_dim",
        "activation",
        "learning_rate",
        "baseline_loss",
        "final_loss",
        "improvement",
        "optimizer_final_loss",
        "world_nontrivial_count",
    ]
    all(key -> haskey(values, key), required) ||
        throw(ArgumentError("TRM run summary is missing required fields"))
    (
        accepted=values["accepted"] == "true",
        sample_count=parse(Int, values["sample_count"]),
        checkpoint_count=parse(Int, values["checkpoint_count"]),
        epochs_per_checkpoint=parse(Int, values["epochs_per_checkpoint"]),
        cumulative_epochs=parse(Int, values["cumulative_epochs"]),
        hidden_dim=parse(Int, values["hidden_dim"]),
        activation=Symbol(values["activation"]),
        learning_rate=parse(Float64, values["learning_rate"]),
        baseline_loss=parse(Float64, values["baseline_loss"]),
        final_loss=parse(Float64, values["final_loss"]),
        improvement=parse(Float64, values["improvement"]),
        optimizer_final_loss=parse(Float64, values["optimizer_final_loss"]),
        world_nontrivial_count=parse(Int, values["world_nontrivial_count"]),
    )
end

function _trm_resume_matches(
    run_summary,
    hidden_dim::Integer,
    learning_rate::Real,
    checkpoint_count::Integer,
    epochs_per_checkpoint::Integer,
)
    run_summary.hidden_dim == Int(hidden_dim) &&
        run_summary.learning_rate == Float64(learning_rate) &&
        run_summary.checkpoint_count == Int(checkpoint_count) &&
        run_summary.epochs_per_checkpoint == Int(epochs_per_checkpoint)
end

function run_trm_neural_training_experiment_sweep(
    adapter::SigmaSystemAdapter,
    initial_action::AbstractVector,
    dc_result::DCResult;
    hidden_dims=[8],
    learning_rates=[1e-2],
    checkpoint_counts=[3],
    epochs_per_checkpoint_values=[10],
    output_dir::Union{AbstractString,Nothing}=nothing,
    resume::Bool=false,
    kwargs...,
)
    hidden_values = Int.(_check_positive_collection(hidden_dims, "hidden_dims"))
    learning_values = Float64.(_check_positive_collection(learning_rates, "learning_rates"))
    checkpoint_values = Int.(_check_positive_collection(checkpoint_counts, "checkpoint_counts"))
    epoch_values = Int.(_check_positive_collection(
        epochs_per_checkpoint_values,
        "epochs_per_checkpoint_values",
    ))

    experiments = Any[]
    entries = NamedTuple[]
    run_index = 0
    for hidden_dim in hidden_values
        for learning_rate in learning_values
            for checkpoint_count in checkpoint_values
                for epochs_per_checkpoint in epoch_values
                    run_index += 1
                    run_dir = output_dir === nothing ? nothing :
                        _trm_sweep_run_dir(output_dir, run_index)
                    run_summary_tsv_path = run_dir === nothing ? nothing :
                        joinpath(run_dir, "run-summary.tsv")
                    if resume &&
                            run_summary_tsv_path !== nothing &&
                            isfile(run_summary_tsv_path)
                        run_summary = _read_trm_neural_run_summary_tsv(run_summary_tsv_path)
                        if _trm_resume_matches(
                            run_summary,
                            hidden_dim,
                            learning_rate,
                            checkpoint_count,
                            epochs_per_checkpoint,
                        )
                            push!(experiments, nothing)
                            push!(entries, (
                                index=run_index,
                                hidden_dim=hidden_dim,
                                learning_rate=learning_rate,
                                checkpoint_count=checkpoint_count,
                                epochs_per_checkpoint=epochs_per_checkpoint,
                                accepted=run_summary.accepted,
                                final_loss=run_summary.final_loss,
                                improvement=run_summary.improvement,
                                output_dir=run_dir,
                                summary_path=joinpath(run_dir, "summary.json"),
                                run_summary_tsv_path=run_summary_tsv_path,
                                resumed=true,
                            ))
                            continue
                        end
                    end
                    experiment = run_trm_neural_training_experiment(
                        adapter,
                        initial_action,
                        dc_result;
                        hidden_dim=hidden_dim,
                        learning_rate=learning_rate,
                        checkpoint_count=checkpoint_count,
                        epochs_per_checkpoint=epochs_per_checkpoint,
                        output_dir=run_dir,
                        kwargs...,
                    )
                    push!(experiments, experiment)
                    push!(entries, (
                        index=run_index,
                        hidden_dim=hidden_dim,
                        learning_rate=learning_rate,
                        checkpoint_count=checkpoint_count,
                        epochs_per_checkpoint=epochs_per_checkpoint,
                        accepted=experiment.summary.accepted,
                        final_loss=experiment.summary.final_loss,
                        improvement=experiment.summary.improvement,
                        output_dir=run_dir,
                        summary_path=hasproperty(experiment.artifact_paths, :summary_path) ?
                            experiment.artifact_paths.summary_path : nothing,
                        run_summary_tsv_path=hasproperty(
                            experiment.artifact_paths,
                            :run_summary_tsv_path,
                        ) ? experiment.artifact_paths.run_summary_tsv_path : nothing,
                        resumed=false,
                    ))
                end
            end
        end
    end

    losses = [entry.final_loss for entry in entries]
    best_index = argmin(losses)
    summary = (
        kind=:TRMNeuralTrainingExperimentSweep,
        run_count=length(entries),
        hidden_dims=hidden_values,
        learning_rates=learning_values,
        checkpoint_counts=checkpoint_values,
        epochs_per_checkpoint_values=epoch_values,
        best_index=entries[best_index].index,
        best_final_loss=entries[best_index].final_loss,
        accepted_count=count(entry -> entry.accepted, entries),
        resumed_count=count(entry -> entry.resumed, entries),
        entries=entries,
    )
    certificate_check = get(kwargs, :certificate_check, nothing)
    artifact_paths = output_dir === nothing ? NamedTuple() :
        _write_trm_neural_sweep_summary(
            output_dir,
            summary;
            certificate_check=certificate_check,
        )
    TRMNeuralTrainingExperimentSweepResult(experiments, summary, artifact_paths)
end
