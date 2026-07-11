using LinearAlgebra
using Random

const WLD_DENSE_THRESHOLD = 256
const WLD_SVD_OVERSAMPLE = 8
const WLD_SVD_POWER_ITERATIONS = 2
const WLD_SVD_SEED = 42

struct TensorGramOperator{T,M<:AbstractMatrix{T}} <: AbstractMatrix{T}
    tensor::M
end

Base.size(operator::TensorGramOperator) =
    (size(operator.tensor, 2), size(operator.tensor, 2))
Base.getindex(operator::TensorGramOperator, i::Int, j::Int) =
    dot(view(operator.tensor, :, i), view(operator.tensor, :, j))
Base.:*(operator::TensorGramOperator, vector::AbstractVector) =
    transpose(operator.tensor) * (operator.tensor * vector)

struct WldResult
    loop::AbstractMatrix
    eigenvalues::Vector
    basis::AbstractMatrix
    selected::Vector{Bool}
    truncated::Bool
end

WldResult(loop, eigenvalues, basis, selected) =
    WldResult(loop, eigenvalues, basis, selected, false)

world_loop_operator(tensor::AbstractMatrix) = transpose(tensor) * tensor

function world_loop_operator(sigma, a)
    world_loop_operator(sensitivity_tensor(sigma, a))
end

function _dense_actuated_world(tensor::AbstractMatrix, target::Real, tol::Real)
    loop = world_loop_operator(tensor)
    decomposition = eigen(Symmetric(loop))
    selected = abs.(decomposition.values .- target) .<= tol
    basis = decomposition.vectors[:, selected]
    WldResult(loop, collect(decomposition.values), basis, collect(selected), false)
end

function _right_singular_system(
    tensor::AbstractMatrix,
    rank::Integer;
    oversample::Integer=WLD_SVD_OVERSAMPLE,
    power_iterations::Integer=WLD_SVD_POWER_ITERATIONS,
    seed::Integer=WLD_SVD_SEED,
)
    limit = min(size(tensor)...)
    1 <= rank <= limit || throw(ArgumentError("rank must be between 1 and min(size(tensor))"))
    oversample >= 0 || throw(ArgumentError("oversample must be nonnegative"))
    power_iterations >= 0 ||
        throw(ArgumentError("power_iterations must be nonnegative"))
    if rank == limit
        decomposition = svd(tensor; full=false)
        return decomposition.S, decomposition.V
    end

    sketch_rank = min(limit, rank + max(0, oversample))
    rng = MersenneTwister(seed)
    sketch = tensor * randn(rng, eltype(float(tensor)), size(tensor, 2), sketch_rank)
    basis = Matrix(qr(sketch).Q[:, 1:sketch_rank])
    for _ in 1:power_iterations
        adjoint_basis = Matrix(qr(transpose(tensor) * basis).Q[:, 1:sketch_rank])
        basis = Matrix(qr(tensor * adjoint_basis).Q[:, 1:sketch_rank])
    end
    compressed = svd(transpose(basis) * tensor; full=false)
    compressed.S[1:rank], compressed.V[:, 1:rank]
end

function _svd_actuated_world(
    tensor::AbstractMatrix,
    target::Real,
    tol::Real,
    rank::Integer,
    oversample::Integer,
    power_iterations::Integer,
    seed::Integer,
)
    singularvalues, right_vectors = _right_singular_system(
        tensor,
        rank;
        oversample=oversample,
        power_iterations=power_iterations,
        seed=seed,
    )
    values = singularvalues .^ 2
    order = sortperm(values)
    eigenvalues = collect(values[order])
    vectors = right_vectors[:, order]
    selected = abs.(eigenvalues .- target) .<= tol
    basis = vectors[:, selected]
    truncated = rank < min(size(tensor)...)
    WldResult(
        TensorGramOperator(tensor),
        eigenvalues,
        basis,
        collect(selected),
        truncated,
    )
end

function actuated_world(
    tensor::AbstractMatrix;
    target::Real=1.0,
    tol::Real=1e-6,
    method::Symbol=:auto,
    rank::Union{Integer,Nothing}=nothing,
    oversample::Integer=WLD_SVD_OVERSAMPLE,
    power_iterations::Integer=WLD_SVD_POWER_ITERATIONS,
    seed::Integer=WLD_SVD_SEED,
)
    method in (:auto, :dense, :svd) ||
        throw(ArgumentError("method must be :auto, :dense, or :svd"))
    isempty(tensor) && throw(ArgumentError("tensor must be nonempty"))
    selected_method = method == :auto ?
        (size(tensor, 2) <= WLD_DENSE_THRESHOLD ? :dense : :svd) : method
    selected_method == :dense && return _dense_actuated_world(tensor, target, tol)
    max_rank = min(size(tensor)...)
    selected_rank = rank === nothing ? max_rank : Int(rank)
    _svd_actuated_world(
        tensor,
        target,
        tol,
        selected_rank,
        oversample,
        power_iterations,
        seed,
    )
end

function actuated_world(sigma, a; kwargs...)
    actuated_world(sensitivity_tensor(sigma, a); kwargs...)
end

world_nontrivial(result::WldResult) = size(result.basis, 2) > 0

function world_admissible(loop::AbstractMatrix, x::AbstractVector, eta::Real)
    eta >= 0 || throw(ArgumentError("eta must be nonnegative"))
    size(loop, 1) == size(loop, 2) ||
        throw(DimensionMismatch("world loop must be square"))
    size(loop, 2) == length(x) ||
        throw(DimensionMismatch("vector length must match world loop"))
    norm(loop * x - x) <= eta * norm(x)
end

function world_band(tensor::AbstractMatrix; eta::Real, kwargs...)
    eta >= 0 || throw(ArgumentError("eta must be nonnegative"))
    actuated_world(tensor; target=1.0, tol=eta, kwargs...)
end

function world_projection(result::WldResult)
    n = size(result.loop, 1)
    world_nontrivial(result) || return zeros(eltype(result.loop), n, n)
    result.basis * transpose(result.basis)
end

struct ReachProbeResult
    overlap_history::Vector{Float64}
    final_overlap::Float64
    iterations::Int
    status::Symbol
    target_is_dominant::Bool
    diagnostic::Symbol
end

ReachProbeResult(overlap_history, final_overlap, iterations, status) =
    ReachProbeResult(
        overlap_history,
        final_overlap,
        iterations,
        status,
        false,
        :not_evaluated,
    )

function _target_is_dominant(wld::WldResult; tol::Real)
    world_nontrivial(wld) || return false
    selected_values = wld.eigenvalues[wld.selected]
    isempty(selected_values) && return false
    spectral_max = maximum(real.(wld.eigenvalues))
    selected_max = maximum(real.(selected_values))
    spectral_max - selected_max <= tol * max(1.0, abs(spectral_max))
end

"""
Probe whether normalized power iteration under `wld.loop` is attracted to the
precomputed Wld projection. This is an algebraic attraction diagnostic, not a
simulation of the underlying physical system. `target_is_dominant=false`
means generic power iteration is not expected to reach the selected target;
`diagnostic` distinguishes that case without changing the three status values.
"""
function wld_reach_probe(
    wld::WldResult,
    initial::AbstractVector;
    max_iters::Integer=1000,
    reach_tol::Real=1e-3,
    conv_tol::Real=1e-8,
)
    length(initial) == size(wld.loop, 2) ||
        throw(DimensionMismatch("initial direction must match the Wld domain"))
    max_iters > 0 || throw(ArgumentError("max_iters must be positive"))
    initial_norm = norm(initial)
    isfinite(initial_norm) && initial_norm > 0 ||
        throw(ArgumentError("initial direction must be finite and nonzero"))
    x = Float64.(initial) / initial_norm
    projection = world_projection(wld)
    history = Float64[]
    target_is_dominant = _target_is_dominant(wld; tol=reach_tol)

    for iteration in 1:max_iters
        next = wld.loop * x
        next_norm = norm(next)
        if !isfinite(next_norm) || next_norm <= eps(Float64)
            overlap = norm(projection * x)
            push!(history, Float64(overlap))
            return ReachProbeResult(
                history,
                last(history),
                iteration,
                :diverged,
                target_is_dominant,
                :zero_iterate,
            )
        end
        next ./= next_norm
        overlap = Float64(norm(projection * next))
        previous_overlap = isempty(history) ? nothing : last(history)
        push!(history, overlap)
        converged = previous_overlap !== nothing &&
            abs(overlap - previous_overlap) < conv_tol
        if overlap > 1 - reach_tol && converged
            diagnostic = target_is_dominant ? :target_attractor : :target_not_dominant
            return ReachProbeResult(
                history,
                overlap,
                iteration,
                :reached,
                target_is_dominant,
                diagnostic,
            )
        end
        x = next
    end

    final_overlap = isempty(history) ? 0.0 : last(history)
    tail = history[max(1, end - 4):end]
    near_zero = final_overlap <= reach_tol
    decreasing = length(tail) < 2 || all(diff(tail) .<= conv_tol)
    stable_near_zero = length(tail) >= 2 && maximum(abs.(diff(tail))) <= conv_tol
    status = near_zero && (decreasing || stable_near_zero) ? :diverged : :non_converged
    diagnostic = !target_is_dominant ? :target_not_dominant :
        status == :diverged ? :overlap_vanished : :iteration_limit
    ReachProbeResult(
        history,
        final_overlap,
        max_iters,
        status,
        target_is_dominant,
        diagnostic,
    )
end

function check_umwelt_relative(
    sigma1,
    a1,
    sigma2,
    a2;
    target::Real=1.0,
    eig_tol::Real=1e-6,
    diff_tol::Real=1e-6,
)
    world1 = actuated_world(sigma1, a1; target=target, tol=eig_tol)
    world2 = actuated_world(sigma2, a2; target=target, tol=eig_tol)
    size(world1.loop) == size(world2.loop) || return true
    norm(world_projection(world1) - world_projection(world2)) > diff_tol
end
