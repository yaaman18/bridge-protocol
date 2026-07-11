@enum LeniaArchitectureStatus begin
    architecture_ok
    architecture_warn
    architecture_reject
    architecture_error
end

struct LeniaArchitectureResult{S,A,N,R,H,Q,C,T,O}
    system::S
    adapter::A
    normalized_adapter::N
    report::R
    harness::H
    reachability::Q
    slowing_assessment::C
    status::T
    artifact::O
    artifact_json::String
end

function architecture_status(harness, reachability, slowing_assessment)
    harness.accepted || return architecture_reject
    reachable = reachability.reachability.reachable
    warning = slowing_assessment.warning
    reachable && !warning ? architecture_ok : architecture_warn
end

function run_lenia_architecture(;
    shape::Tuple{Int,Int}=(5, 5),
    action_count::Integer=16,
    feature_count::Integer=32,
    kernel_size::Integer=5,
    tau_steps::Integer=1,
    mu::Real=0.15,
    sigma::Real=0.05,
    dt::Real=0.1,
    action::Union{AbstractVector,Nothing}=nothing,
    initial_field=nothing,
    initial_condition::Union{LeniaInitialConditionConfig,Nothing}=nothing,
    dc_result::DCResult=DCResult(true, true, true, true, Set([:lenia_act])),
    epsilon_features=nothing,
    require_reachable::Bool=true,
    slowing_config::CriticalSlowingConfig=CriticalSlowingConfig(),
    artifact_path::Union{AbstractString,Nothing}=nothing,
    certificate_check::Union{CertifiedArtifactCheck,Nothing}=nothing,
    eig_tol::Real=1e-6,
    fixed_tol::Real=1e-5,
    wld_method::Symbol=:auto,
    wld_rank::Union{Integer,Nothing}=nothing,
    wld_oversample::Integer=WLD_SVD_OVERSAMPLE,
    wld_power_iterations::Integer=WLD_SVD_POWER_ITERATIONS,
    wld_seed::Integer=WLD_SVD_SEED,
)
    initial_field !== nothing && initial_condition !== nothing &&
        throw(ArgumentError("initial_field and initial_condition cannot both be provided"))
    selected_action = action === nothing ? zeros(Int(action_count)) : action
    field = initial_field !== nothing ? initial_field : lenia_initial_field(
        shape;
        config=initial_condition === nothing ? LeniaInitialConditionConfig() : initial_condition,
    )
    config = LeniaAdapterConfig(
        mu=mu,
        sigma=sigma,
        dt=dt,
        tau_steps=tau_steps,
        feature_count=feature_count,
    )
    system = default_lenia_system(
        shape;
        action_count=action_count,
        feature_count=feature_count,
        kernel_size=kernel_size,
        config=config,
    )
    action_contract = lenia_body_action_contract(system)
    adapter = lenia_system_adapter(system, field)
    normalized = normalized_system_adapter(adapter, selected_action)
    report = observation_structure_report(
        normalized,
        selected_action,
        dc_result;
        eig_tol=eig_tol,
        fixed_tol=fixed_tol,
        action_index=1,
        interoceptive_signal=[0.1],
        wld_method=wld_method,
        wld_rank=wld_rank,
        wld_oversample=wld_oversample,
        wld_power_iterations=wld_power_iterations,
        wld_seed=wld_seed,
    )
    tensor = report.pipeline.tensor
    feature_count_actual = size(tensor, 1)
    selected_epsilon = epsilon_features === nothing ?
        Set(1:feature_count_actual) : Set(epsilon_features)
    feature_order = FinitePreorder(collect(1:feature_count_actual), <=)
    reachability = ordered_reachable_world_projection(
        report.pipeline.wld_result,
        feature_order,
        selected_epsilon,
        feature_direction_map(tensor);
        tol=eig_tol,
    )
    harness = dc_world_harness(
        dc_result,
        report.pipeline.wld_result;
        direction=report.pipeline.bridge.direction,
        reachability=reachability.reachability,
        require_reachable=require_reachable,
        fixed_tol=fixed_tol,
    )
    slowing_assessment = critical_slowing_assessment(
        [report.pipeline.wld_result];
        config=slowing_config,
    )
    status_code = architecture_status(harness, reachability, slowing_assessment)
    status = (
        code=status_code,
        world_nontrivial=world_nontrivial(report.pipeline.wld_result),
        reachable=reachability.reachability.reachable,
        harness_accepted=harness.accepted,
        slowing_warning=slowing_assessment.warning,
        classification=report.pipeline.classification,
        action_profile=action_contract.profile,
        action_semantics=action_contract.action_semantics,
        kernel_parameter_role=action_contract.kernel_parameter_role,
        action_count=action_contract.action_count,
        production_action_dimension=action_contract.production_dimension,
        initial_condition_mode=initial_condition === nothing ? :zeros : initial_condition.mode,
        initial_condition_seed=initial_condition === nothing ? nothing : initial_condition.seed,
        artifact_ready=true,
    )
    fingerprint = lenia_system_fingerprint(system, selected_action, field)
    artifact = observation_timeseries_artifact(
        [report];
        system_fingerprint=fingerprint,
        times=[0],
    )
    artifact_json = certificate_check === nothing ?
        observation_artifact_json(artifact) :
        certified_observation_artifact_json(artifact, certificate_check)
    if artifact_path !== nothing
        certificate_check === nothing ?
            write_observation_artifact(artifact_path, artifact) :
            write_certified_observation_artifact(artifact_path, artifact, certificate_check)
    end
    LeniaArchitectureResult(
        system,
        adapter,
        normalized,
        report,
        harness,
        reachability,
        slowing_assessment,
        status,
        artifact,
        artifact_json,
    )
end

function summarize_lenia_architecture(result::LeniaArchitectureResult)
    (
        status=result.status,
        dominant_eigenvalue=dominant_world_eigenvalue(result.report.pipeline.wld_result),
        reachability_overlap=result.reachability.reachability.overlap_norm,
        harness=result.harness.assumptions,
        bridge=summarize_worlddc_bridge(result.harness.bridge),
        system_fingerprint=result.artifact.system_fingerprint,
        phenomenal_claim=result.artifact.phenomenal_claim,
    )
end

function lenia_architecture_status_certificate(result::LeniaArchitectureResult)
    summary = summarize_lenia_architecture(result)
    (
        kind=:LeniaArchitectureStatus,
        ok=result.status.artifact_ready &&
            result.status.world_nontrivial &&
            result.status.harness_accepted,
        julia_unverified_execution_boundary()...,
        lean_contracts=["worlddc.bridge"],
        julia_checkers=[
            :architecture_status,
            :check_worlddc_bridge,
            :check_ordered_wld_reachable,
            :critical_slowing_assessment,
        ],
        numeric_assumptions=(
            dominant_eigenvalue=summary.dominant_eigenvalue,
            reachability_overlap=summary.reachability_overlap,
            fixed_residual=summary.bridge.fixed_residual,
            action_count=result.status.action_count,
            initial_condition_seed=result.status.initial_condition_seed,
        ),
        status=string(result.status.code),
        world_nontrivial=result.status.world_nontrivial,
        reachable=result.status.reachable,
        harness_accepted=result.status.harness_accepted,
        slowing_warning=result.status.slowing_warning,
        classification=result.status.classification,
        action_profile=result.status.action_profile,
        action_semantics=result.status.action_semantics,
        kernel_parameter_role=result.status.kernel_parameter_role,
        production_action_dimension=result.status.production_action_dimension,
        initial_condition_mode=result.status.initial_condition_mode,
        system_fingerprint=result.artifact.system_fingerprint,
        phenomenal_claim=result.artifact.phenomenal_claim,
    )
end

function certified_lenia_architecture_status(
    result::LeniaArchitectureResult,
    check::CertifiedArtifactCheck,
)
    instance_certificate = lenia_architecture_status_certificate(result)
    instance_certificate.ok ||
        throw(ArgumentError("cannot certify an invalid Lenia architecture status"))
    certified_artifact_envelope(instance_certificate, check)
end

certified_lenia_architecture_status_json(
    result::LeniaArchitectureResult,
    check::CertifiedArtifactCheck,
) = _json_value(certified_lenia_architecture_status(result, check))

function _lenia_reproducibility_certificate_data(series, expected_count::Integer)
    values = hasproperty(series, :reproducibility) ? series.reproducibility : Any[]
    enabled = any(value -> value !== nothing, values)
    complete = !enabled ||
        (length(values) == expected_count && all(value -> value !== nothing, values))
    assessments = enabled && complete ? collect(values) : Any[]
    accepted = complete && all(assessment -> assessment.accepted, assessments)
    (
        ok=accepted,
        enabled=enabled,
        assessment_count=length(assessments),
        accepted_count=count(assessment -> assessment.accepted, assessments),
        seeds=[assessment.seed for assessment in assessments],
        repeats=[assessment.repeats for assessment in assessments],
        relative_tolerances=[assessment.relative_tolerance for assessment in assessments],
        max_relative_deviations=[
            assessment.max_relative_deviation for assessment in assessments
        ],
    )
end

function lenia_tau_sweep_certificate(series)
    results = series.results
    summaries = series.summary
    !isempty(results) || throw(ArgumentError("Lenia tau sweep must contain at least one result"))
    status_ok = all(
        result.status.artifact_ready &&
            result.status.world_nontrivial &&
            result.status.harness_accepted
        for result in results
    )
    reproducibility = _lenia_reproducibility_certificate_data(series, length(results))
    (
        kind=:LeniaTauSweep,
        ok=status_ok && reproducibility.ok && length(results) == length(summaries),
        julia_unverified_execution_boundary()...,
        lean_contracts=["worlddc.bridge"],
        julia_checkers=[
            :compare_lenia_tau_steps,
            :lenia_architecture_status_certificate,
            :ordered_reachable_world_projection,
            :critical_slowing_assessment,
            :reproducibility_assessment,
        ],
        numeric_assumptions=(
            tau_steps=[summary.tau_step for summary in summaries],
            projection_distances=[summary.projection_distance for summary in summaries],
            dominant_eigenvalues=[summary.dominant_eigenvalue for summary in summaries],
            slowing_warnings=[summary.slowing_warning for summary in summaries],
            reproducibility_seeds=reproducibility.seeds,
            reproducibility_repeats=reproducibility.repeats,
            reproducibility_relative_tolerances=reproducibility.relative_tolerances,
            reproducibility_max_relative_deviations=
                reproducibility.max_relative_deviations,
        ),
        result_count=length(results),
        reachable_count=count(result -> result.status.reachable, results),
        harness_accepted_count=count(result -> result.status.harness_accepted, results),
        slowing_warning_count=count(result -> result.status.slowing_warning, results),
        status_codes=[string(result.status.code) for result in results],
        classifications=[result.status.classification for result in results],
        reproducibility_enabled=reproducibility.enabled,
        reproducibility_assessment_count=reproducibility.assessment_count,
        reproducibility_accepted_count=reproducibility.accepted_count,
    )
end

function certified_lenia_tau_sweep(series, check::CertifiedArtifactCheck)
    instance_certificate = lenia_tau_sweep_certificate(series)
    instance_certificate.ok ||
        throw(ArgumentError("cannot certify an invalid Lenia tau sweep"))
    certified_artifact_envelope(instance_certificate, check)
end

certified_lenia_tau_sweep_json(series, check::CertifiedArtifactCheck) =
    _json_value(certified_lenia_tau_sweep(series, check))

function lenia_feature_sweep_certificate(series)
    results = series.results
    summaries = series.summary
    !isempty(results) || throw(ArgumentError("Lenia feature sweep must contain at least one result"))
    status_ok = all(
        result.status.artifact_ready &&
            result.status.world_nontrivial &&
            result.status.harness_accepted
        for result in results
    )
    reproducibility = _lenia_reproducibility_certificate_data(series, length(results))
    (
        kind=:LeniaFeatureSweep,
        ok=status_ok && reproducibility.ok && length(results) == length(summaries),
        julia_unverified_execution_boundary()...,
        lean_contracts=["worlddc.bridge"],
        julia_checkers=[
            :compare_lenia_feature_counts,
            :lenia_architecture_status_certificate,
            :ordered_reachable_world_projection,
            :critical_slowing_assessment,
            :reproducibility_assessment,
        ],
        numeric_assumptions=(
            feature_counts=[summary.feature_count for summary in summaries],
            projection_distances=[summary.projection_distance for summary in summaries],
            dominant_eigenvalues=[summary.dominant_eigenvalue for summary in summaries],
            slowing_warnings=[summary.slowing_warning for summary in summaries],
            reproducibility_seeds=reproducibility.seeds,
            reproducibility_repeats=reproducibility.repeats,
            reproducibility_relative_tolerances=reproducibility.relative_tolerances,
            reproducibility_max_relative_deviations=
                reproducibility.max_relative_deviations,
        ),
        result_count=length(results),
        reachable_count=count(result -> result.status.reachable, results),
        harness_accepted_count=count(result -> result.status.harness_accepted, results),
        slowing_warning_count=count(result -> result.status.slowing_warning, results),
        status_codes=[string(result.status.code) for result in results],
        classifications=[result.status.classification for result in results],
        reproducibility_enabled=reproducibility.enabled,
        reproducibility_assessment_count=reproducibility.assessment_count,
        reproducibility_accepted_count=reproducibility.accepted_count,
    )
end

function certified_lenia_feature_sweep(series, check::CertifiedArtifactCheck)
    instance_certificate = lenia_feature_sweep_certificate(series)
    instance_certificate.ok ||
        throw(ArgumentError("cannot certify an invalid Lenia feature sweep"))
    certified_artifact_envelope(instance_certificate, check)
end

certified_lenia_feature_sweep_json(series, check::CertifiedArtifactCheck) =
    _json_value(certified_lenia_feature_sweep(series, check))

function lenia_parameter_grid_certificate(series)
    entries = series.results
    summaries = series.summary
    !isempty(entries) || throw(ArgumentError("Lenia parameter grid must contain at least one result"))
    architecture_results = [entry.result for entry in entries]
    status_ok = all(
        result.status.artifact_ready &&
            result.status.world_nontrivial &&
            result.status.harness_accepted
        for result in architecture_results
    )
    reproducibility = _lenia_reproducibility_certificate_data(series, length(entries))
    (
        kind=:LeniaParameterGrid,
        ok=status_ok && reproducibility.ok && length(entries) == length(summaries),
        julia_unverified_execution_boundary()...,
        lean_contracts=["worlddc.bridge"],
        julia_checkers=[
            :compare_lenia_parameter_grid,
            :lenia_architecture_status_certificate,
            :ordered_reachable_world_projection,
            :critical_slowing_assessment,
            :reproducibility_assessment,
        ],
        numeric_assumptions=(
            tau_steps=[summary.tau_step for summary in summaries],
            feature_counts=[summary.feature_count for summary in summaries],
            projection_distances=[summary.projection_distance for summary in summaries],
            dominant_eigenvalues=[summary.dominant_eigenvalue for summary in summaries],
            slowing_warnings=[summary.slowing_warning for summary in summaries],
            reproducibility_seeds=reproducibility.seeds,
            reproducibility_repeats=reproducibility.repeats,
            reproducibility_relative_tolerances=reproducibility.relative_tolerances,
            reproducibility_max_relative_deviations=
                reproducibility.max_relative_deviations,
        ),
        result_count=length(entries),
        tau_count=length(unique(summary.tau_step for summary in summaries)),
        feature_count=length(unique(summary.feature_count for summary in summaries)),
        reachable_count=count(result -> result.status.reachable, architecture_results),
        harness_accepted_count=count(result -> result.status.harness_accepted, architecture_results),
        slowing_warning_count=count(result -> result.status.slowing_warning, architecture_results),
        status_codes=[string(result.status.code) for result in architecture_results],
        classifications=[result.status.classification for result in architecture_results],
        reproducibility_enabled=reproducibility.enabled,
        reproducibility_assessment_count=reproducibility.assessment_count,
        reproducibility_accepted_count=reproducibility.accepted_count,
    )
end

function certified_lenia_parameter_grid(series, check::CertifiedArtifactCheck)
    instance_certificate = lenia_parameter_grid_certificate(series)
    instance_certificate.ok ||
        throw(ArgumentError("cannot certify an invalid Lenia parameter grid"))
    certified_artifact_envelope(instance_certificate, check)
end

certified_lenia_parameter_grid_json(series, check::CertifiedArtifactCheck) =
    _json_value(certified_lenia_parameter_grid(series, check))

function _lenia_reproducibility_trial(
    run_arguments::NamedTuple,
    acceptance_config::Union{ExperimentAcceptanceConfig,Nothing},
)
    if acceptance_config === nothing
        result = run_lenia_architecture(; run_arguments...)
        return (result=result, runs=[result], reproducibility=nothing)
    end

    defaults = (
        eig_tol=acceptance_config.eig_tol,
        slowing_config=CriticalSlowingConfig(
            lambda_threshold=acceptance_config.lambda_threshold,
            eig_tol=acceptance_config.eig_tol,
        ),
    )
    effective_arguments = merge(defaults, run_arguments)
    trial = run_reproducibility_trials(
        (seed, replicate) -> begin
            arguments = effective_arguments
            if haskey(arguments, :initial_condition) &&
                    arguments.initial_condition !== nothing
                condition = _lenia_initial_condition_with_seed(
                    arguments.initial_condition,
                    seed + replicate - 1,
                )
                arguments = merge(arguments, (initial_condition=condition,))
            end
            arguments = merge(arguments, (wld_seed=seed + replicate - 1,))
            run_lenia_architecture(; arguments...)
        end;
        metric=result -> dominant_world_eigenvalue(result.report.pipeline.wld_result),
        config=acceptance_config,
    )
    (
        result=first(trial.runs),
        runs=trial.runs,
        reproducibility=trial.assessment,
    )
end

function _lenia_series_artifact_json(artifacts, reproducibility, certificate_check)
    collection = ObservationArtifactCollection(collect(artifacts))
    metadata = (reproducibility=reproducibility,)
    certificate_check === nothing ?
        observation_artifact_collection_json(collection; metadata=metadata) :
        certified_observation_artifact_collection_json(
            collection,
            certificate_check;
            metadata=metadata,
        )
end

function compare_lenia_tau_steps(
    tau_steps;
    certificate_check::Union{CertifiedArtifactCheck,Nothing}=nothing,
    acceptance_config::Union{ExperimentAcceptanceConfig,Nothing}=ExperimentAcceptanceConfig(),
    kwargs...,
)
    tau_values = collect(tau_steps)
    !isempty(tau_values) || throw(ArgumentError("tau_steps must contain at least one value"))
    trials = [
        _lenia_reproducibility_trial(
            merge(
                NamedTuple(kwargs),
                (tau_steps=tau_step, certificate_check=certificate_check),
            ),
            acceptance_config,
        )
        for tau_step in tau_values
    ]
    results = [trial.result for trial in trials]
    reproducibility = [trial.reproducibility for trial in trials]
    reference_projection = world_projection(first(results).report.pipeline.wld_result)
    summary = [
        (
            tau_step=tau_step,
            projection_distance=norm(
                world_projection(result.report.pipeline.wld_result) - reference_projection,
            ),
            dominant_eigenvalue=dominant_world_eigenvalue(result.report.pipeline.wld_result),
            slowing_warning=result.slowing_assessment.warning,
            classification=result.report.pipeline.classification,
            harness_accepted=result.harness.accepted,
            reachable=result.reachability.reachability.reachable,
            status=result.status.code,
            reproducibility=trial.reproducibility,
        )
        for (tau_step, result, trial) in zip(tau_values, results, trials)
    ]
    reports = [result.report for result in results]
    (
        results=results,
        replicates=[trial.runs for trial in trials],
        reproducibility=reproducibility,
        reports=reports,
        summary=summary,
        artifact_json=_lenia_series_artifact_json(
            [result.artifact for result in results],
            reproducibility,
            certificate_check,
        ),
    )
end

function compare_lenia_parameter_grid(
    tau_steps,
    feature_counts;
    certificate_check::Union{CertifiedArtifactCheck,Nothing}=nothing,
    acceptance_config::Union{ExperimentAcceptanceConfig,Nothing}=ExperimentAcceptanceConfig(),
    kwargs...,
)
    tau_values = collect(tau_steps)
    feature_values = collect(feature_counts)
    !isempty(tau_values) || throw(ArgumentError("tau_steps must contain at least one value"))
    !isempty(feature_values) || throw(ArgumentError("feature_counts must contain at least one value"))
    trials = [
        (
            tau_step=tau_step,
            feature_count=feature_count,
            trial=_lenia_reproducibility_trial(
                merge(
                    NamedTuple(kwargs),
                    (
                        tau_steps=tau_step,
                        feature_count=feature_count,
                        certificate_check=certificate_check,
                    ),
                ),
                acceptance_config,
            ),
        )
        for tau_step in tau_values
        for feature_count in feature_values
    ]
    entries = [
        (
            tau_step=entry.tau_step,
            feature_count=entry.feature_count,
            result=entry.trial.result,
            replicates=entry.trial.runs,
            reproducibility=entry.trial.reproducibility,
        )
        for entry in trials
    ]
    reference_projection = world_projection(first(entries).result.report.pipeline.wld_result)
    summary = [
        (
            tau_step=entry.tau_step,
            feature_count=entry.feature_count,
            projection_distance=norm(
                world_projection(entry.result.report.pipeline.wld_result) - reference_projection,
            ),
            dominant_eigenvalue=dominant_world_eigenvalue(entry.result.report.pipeline.wld_result),
            slowing_warning=entry.result.slowing_assessment.warning,
            classification=entry.result.report.pipeline.classification,
            harness_accepted=entry.result.harness.accepted,
            reachable=entry.result.reachability.reachability.reachable,
            status=entry.result.status.code,
            reproducibility=entry.reproducibility,
        )
        for entry in entries
    ]
    reports = [entry.result.report for entry in entries]
    reproducibility = [entry.reproducibility for entry in entries]
    (
        results=entries,
        reproducibility=reproducibility,
        reports=reports,
        summary=summary,
        artifact_json=_lenia_series_artifact_json(
            [entry.result.artifact for entry in entries],
            reproducibility,
            certificate_check,
        ),
    )
end

function compare_lenia_feature_counts(
    feature_counts;
    certificate_check::Union{CertifiedArtifactCheck,Nothing}=nothing,
    acceptance_config::Union{ExperimentAcceptanceConfig,Nothing}=ExperimentAcceptanceConfig(),
    kwargs...,
)
    feature_values = collect(feature_counts)
    !isempty(feature_values) ||
        throw(ArgumentError("feature_counts must contain at least one value"))
    trials = [
        _lenia_reproducibility_trial(
            merge(
                NamedTuple(kwargs),
                (feature_count=feature_count, certificate_check=certificate_check),
            ),
            acceptance_config,
        )
        for feature_count in feature_values
    ]
    results = [trial.result for trial in trials]
    reproducibility = [trial.reproducibility for trial in trials]
    reference_projection = world_projection(first(results).report.pipeline.wld_result)
    summary = [
        (
            feature_count=feature_count,
            projection_distance=norm(
                world_projection(result.report.pipeline.wld_result) - reference_projection,
            ),
            dominant_eigenvalue=dominant_world_eigenvalue(result.report.pipeline.wld_result),
            slowing_warning=result.slowing_assessment.warning,
            classification=result.report.pipeline.classification,
            harness_accepted=result.harness.accepted,
            reachable=result.reachability.reachability.reachable,
            status=result.status.code,
            reproducibility=trial.reproducibility,
        )
        for (feature_count, result, trial) in zip(feature_values, results, trials)
    ]
    reports = [result.report for result in results]
    (
        results=results,
        replicates=[trial.runs for trial in trials],
        reproducibility=reproducibility,
        reports=reports,
        summary=summary,
        artifact_json=_lenia_series_artifact_json(
            [result.artifact for result in results],
            reproducibility,
            certificate_check,
        ),
    )
end
