struct CollapseTraceResult
    actions::Vector
    eigenvalues::Vector{Float64}
    dimensions::Vector{Int}
    slowing_scores::Vector{Float64}
    collapsed_at::Union{Int,Nothing}
end

function world_collapse_trace(
    adapter::SigmaSystemAdapter,
    actions;
    target::Real=1.0,
    eig_tol::Real=1e-6,
    collapse_dimension::Integer=0,
)
    copied_actions = [copy(action) for action in actions]
    worlds = [
        system_actuated_world(adapter, action; target=target, tol=eig_tol)
        for action in copied_actions
    ]
    eigenvalues = [Float64(dominant_world_eigenvalue(world)) for world in worlds]
    dimensions = [size(world.basis, 2) for world in worlds]
    slowing_scores = [
        Float64(critical_slowing_score(world; target=target))
        for world in worlds
    ]
    collapsed_at = findfirst(dim -> dim <= collapse_dimension, dimensions)
    CollapseTraceResult(copied_actions, eigenvalues, dimensions, slowing_scores, collapsed_at)
end

function world_dimension_series(trace::CollapseTraceResult)
    (
        eigenvalues=trace.eigenvalues,
        dimensions=trace.dimensions,
        slowing_scores=trace.slowing_scores,
        collapsed_at=trace.collapsed_at,
    )
end
