using LinearAlgebra

struct MinimalPolicy
    gain::Float64
    use_world::Bool
    normalize::Bool
end

MinimalPolicy(; gain::Real=1.0, use_world::Bool=true, normalize::Bool=true) =
    MinimalPolicy(Float64(gain), use_world, normalize)

function minimal_policy_action(
    policy::MinimalPolicy,
    tensor::AbstractMatrix,
    wld_result::Union{WldResult,Nothing}=nothing;
    tol::Real=1e-10,
)
    n_actions = size(tensor, 2)
    scores = vec(sum(abs.(tensor), dims=1))

    if policy.use_world && wld_result !== nothing
        size(wld_result.loop, 1) == n_actions ||
            throw(DimensionMismatch("world loop dimension must match action dimension"))
        scores = world_projection(wld_result) * scores
    end

    score_norm = norm(scores)
    if score_norm <= tol
        return zeros(eltype(scores), n_actions)
    end

    action = policy.normalize ? scores / score_norm : scores
    policy.gain * action
end

function consume(policy::MinimalPolicy, payload)
    tensor = hasproperty(payload, :weighted_tensor) ? payload.weighted_tensor :
        hasproperty(payload, :tensor) ? payload.tensor :
        throw(ArgumentError("payload must expose tensor or weighted_tensor"))
    wld_result = hasproperty(payload, :wld_result) ? payload.wld_result : nothing
    minimal_policy_action(policy, tensor, wld_result)
end
