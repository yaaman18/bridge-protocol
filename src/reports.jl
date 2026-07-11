struct ObservationStructureReport
    pipeline::SystemPipelineResult
    policy_action::AbstractVector
    benchmark::FourReferenceBenchmark
    collapse::CollapseTraceResult
    summary::NamedTuple
end

function observation_structure_report(
    adapter::SigmaSystemAdapter,
    action::AbstractVector,
    dc_result::DCResult;
    weights::Union{AbstractVector,Nothing}=nothing,
    direction::Union{AbstractVector,Nothing}=nothing,
    target::Real=1.0,
    eig_tol::Real=1e-6,
    fixed_tol::Real=1e-6,
    reachable_directions=nothing,
    action_index::Integer=1,
    fm1_with_action::Bool=true,
    fm1_without_action::Bool=false,
    interoceptive_signal=[1.0],
    policy::MinimalPolicy=MinimalPolicy(),
    collapse_actions=[action],
    wld_method::Symbol=:auto,
    wld_rank::Union{Integer,Nothing}=nothing,
    wld_oversample::Integer=WLD_SVD_OVERSAMPLE,
    wld_power_iterations::Integer=WLD_SVD_POWER_ITERATIONS,
    wld_seed::Integer=WLD_SVD_SEED,
)
    pipeline = run_system_pipeline(
        adapter,
        action,
        dc_result;
        weights=weights,
        direction=direction,
        target=target,
        eig_tol=eig_tol,
        fixed_tol=fixed_tol,
        reachable_directions=reachable_directions,
        action_index=action_index,
        fm1_with_action=fm1_with_action,
        fm1_without_action=fm1_without_action,
        interoceptive_signal=interoceptive_signal,
        wld_method=wld_method,
        wld_rank=wld_rank,
        wld_oversample=wld_oversample,
        wld_power_iterations=wld_power_iterations,
        wld_seed=wld_seed,
    )
    policy_action = consume(policy, pipeline)
    benchmark = run_reference_benchmarks(
        adapter,
        action,
        dc_result;
        direction=direction === nothing ? pipeline.bridge.direction : direction,
        target=target,
        eig_tol=eig_tol,
        fixed_tol=fixed_tol,
        action_index=action_index,
        interoceptive_signal=interoceptive_signal,
    )
    collapse = world_collapse_trace(
        adapter,
        collapse_actions;
        target=target,
        eig_tol=eig_tol,
    )
    summary = (
        pipeline=summarize_pipeline_result(pipeline),
        policy_action=policy_action,
        benchmark_passed=benchmark_passed(benchmark),
        collapse=world_dimension_series(collapse),
    )
    ObservationStructureReport(pipeline, policy_action, benchmark, collapse, summary)
end

function observation_artifact(report::ObservationStructureReport)
    (
        T=report.pipeline.tensor,
        V=report.pipeline.weights,
        O_hat=report.pipeline.weighted_tensor,
        Wld_projection=world_projection(report.pipeline.wld_result),
        slowing_series=world_dimension_series(report.collapse),
        classification=report.pipeline.classification,
        policy_action=report.policy_action,
    )
end

_json_escape(value::AbstractString) =
    replace(value, "\\" => "\\\\", "\"" => "\\\"", "\n" => "\\n")

function _json_value(value)
    if value === nothing
        return "null"
    elseif value isa Bool
        return value ? "true" : "false"
    elseif value isa Symbol
        return "\"" * _json_escape(String(value)) * "\""
    elseif value isa AbstractString
        return "\"" * _json_escape(value) * "\""
    elseif value isa Real
        return string(value)
    elseif value isa AbstractMatrix
        rows = [
            "[" * join((_json_value(value[i, j]) for j in axes(value, 2)), ",") * "]"
            for i in axes(value, 1)
        ]
        return "[" * join(rows, ",") * "]"
    elseif value isa AbstractVector || value isa Tuple
        return "[" * join((_json_value(item) for item in value), ",") * "]"
    elseif value isa NamedTuple
        fields = [
            "\"" * String(key) * "\":" * _json_value(getfield(value, key))
            for key in keys(value)
        ]
        return "{" * join(fields, ",") * "}"
    end
    "\"" * _json_escape(string(value)) * "\""
end

observation_artifact_json(report::ObservationStructureReport) =
    _json_value(observation_artifact(report))

function observation_series_artifact(reports)
    (
        frames=[observation_artifact(report) for report in reports],
        classifications=[report.pipeline.classification for report in reports],
        slowing=[world_dimension_series(report.collapse) for report in reports],
    )
end

observation_series_artifact_json(reports) =
    _json_value(observation_series_artifact(reports))

function write_observation_artifact(path::AbstractString, report::ObservationStructureReport)
    open(path, "w") do io
        write(io, observation_artifact_json(report))
        write(io, "\n")
    end
    path
end

function write_observation_series_artifact(path::AbstractString, reports)
    open(path, "w") do io
        write(io, observation_series_artifact_json(reports))
        write(io, "\n")
    end
    path
end
