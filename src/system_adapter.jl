struct SigmaSystemAdapter{S,U,F}
    state::S
    update::U
    feature_extractor::F
end

system_state(adapter::SigmaSystemAdapter, action::AbstractVector) =
    adapter.update(adapter.state, action)

function advance_system_adapter(adapter::SigmaSystemAdapter, action::AbstractVector)
    SigmaSystemAdapter(
        system_state(adapter, action),
        adapter.update,
        adapter.feature_extractor,
    )
end

system_features(adapter::SigmaSystemAdapter, action::AbstractVector) =
    collect(adapter.feature_extractor(system_state(adapter, action)))

system_sigma(adapter::SigmaSystemAdapter) =
    action -> system_features(adapter, action)

function check_sigma_dimensions(
    adapter::SigmaSystemAdapter,
    action::AbstractVector;
    n_M::Union{Int,Nothing}=length(action),
    n_E::Union{Int,Nothing}=nothing,
)
    n_M === nothing || length(action) == n_M || return false
    features = system_features(adapter, action)
    n_E === nothing || length(features) == n_E || return false
    true
end

function system_sensitivity_tensor(adapter::SigmaSystemAdapter, action::AbstractVector)
    sensitivity_tensor(system_sigma(adapter), action)
end

function system_actuated_world(
    adapter::SigmaSystemAdapter,
    action::AbstractVector;
    target::Real=1.0,
    tol::Real=1e-6,
    kwargs...,
)
    actuated_world(system_sigma(adapter), action; target=target, tol=tol, kwargs...)
end

function normalized_system_adapter(
    adapter::SigmaSystemAdapter,
    reference_action::AbstractVector;
    target::Real=1.0,
    tol::Real=1e-12,
)
    tensor = system_sensitivity_tensor(adapter, reference_action)
    lambda = dominant_world_eigenvalue(world_loop_operator(tensor))
    lambda > tol || throw(ArgumentError("reference system has no nonzero world loop eigenvalue"))
    scale = sqrt(Float64(target) / Float64(lambda))
    SigmaSystemAdapter(
        adapter.state,
        adapter.update,
        state -> scale .* collect(adapter.feature_extractor(state)),
    )
end

struct SystemPipelineResult
    action::AbstractVector
    sensory::AbstractVector
    tensor::AbstractMatrix
    weights::AbstractVector
    weighted_tensor::AbstractMatrix
    wld_result::WldResult
    bridge
    summary::NamedTuple
    reachability::Union{ReachabilityResult,Nothing}
    slowing_score::Float64
    markers::Union{FMMarkers,Nothing}
    classification::Union{Symbol,Nothing}
end

function run_system_pipeline(
    adapter::SigmaSystemAdapter,
    action::AbstractVector,
    dc_result::DCResult;
    weights::Union{AbstractVector,Nothing}=nothing,
    direction::Union{AbstractVector,Nothing}=nothing,
    target::Real=1.0,
    eig_tol::Real=1e-6,
    fixed_tol::Real=1e-6,
    reachable_directions=nothing,
    action_index::Union{Integer,Nothing}=nothing,
    fm1_with_action::Union{Bool,Nothing}=nothing,
    fm1_without_action::Union{Bool,Nothing}=nothing,
    interoceptive_signal=nothing,
    wld_method::Symbol=:auto,
    wld_rank::Union{Integer,Nothing}=nothing,
    wld_oversample::Integer=WLD_SVD_OVERSAMPLE,
    wld_power_iterations::Integer=WLD_SVD_POWER_ITERATIONS,
    wld_seed::Integer=WLD_SVD_SEED,
)
    sensory = system_features(adapter, action)
    tensor = system_sensitivity_tensor(adapter, action)
    selected_weights = weights === nothing ? ones(size(tensor, 2)) : weights
    weighted_tensor = weighted_sensitivity(tensor, selected_weights)
    wld_result = actuated_world(
        tensor;
        target=target,
        tol=eig_tol,
        method=wld_method,
        rank=wld_rank,
        oversample=wld_oversample,
        power_iterations=wld_power_iterations,
        seed=wld_seed,
    )
    selected_direction = direction === nothing ? world_fixed_direction(wld_result) : direction
    bridge = DCWorldBridge(dc_result, wld_result, selected_direction; fixed_tol=fixed_tol)
    summary = summarize_observation(sensory, wld_result, dc_result)
    reachability = reachable_directions === nothing ? nothing :
        reachable_world_projection(wld_result, reachable_directions)
    slowing_score = critical_slowing_score(wld_result; target=target)

    markers = nothing
    classification = nothing
    if action_index !== nothing && fm1_with_action !== nothing &&
            fm1_without_action !== nothing && interoceptive_signal !== nothing
        markers = FMMarkers(
            fm1_global_participation(fm1_with_action, fm1_without_action),
            fm2_sensorimotor_integration(tensor, action_index),
            fm3_self_monitoring(interoceptive_signal),
            fm4_world_participation(wld_result, action_index),
        )
        classification = classify_action_markers(markers)
    end

    SystemPipelineResult(
        copy(action),
        sensory,
        tensor,
        copy(selected_weights),
        weighted_tensor,
        wld_result,
        bridge,
        summary,
        reachability,
        slowing_score,
        markers,
        classification,
    )
end

function summarize_pipeline_result(result::SystemPipelineResult)
    (
        action=result.action,
        sensory=result.summary.sensory_summary,
        world=result.summary.world_summary,
        dc=result.summary.dc_summary,
        reachable=result.reachability === nothing ? nothing : result.reachability.reachable,
        reachability_overlap=result.reachability === nothing ? nothing : result.reachability.overlap_norm,
        slowing_score=result.slowing_score,
        markers=result.markers,
        classification=result.classification,
    )
end
