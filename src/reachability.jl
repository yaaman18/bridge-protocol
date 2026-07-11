using LinearAlgebra

struct ReachabilityResult
    projection::AbstractMatrix
    reachable_projection::AbstractMatrix
    overlap_norm::Float64
    reachable::Bool
end

function _orthonormal_basis(directions::AbstractMatrix; tol::Real=1e-10)
    isempty(directions) && return zeros(eltype(directions), size(directions, 1), 0)
    decomposition = svd(directions)
    keep = decomposition.S .> tol
    decomposition.U[:, keep]
end

function reachable_world_projection(
    wld_result::WldResult,
    reachable_directions::AbstractMatrix;
    tol::Real=1e-10,
)
    size(reachable_directions, 1) == size(wld_result.loop, 1) ||
        throw(DimensionMismatch("reachable direction rows must match world dimension"))
    projection = world_projection(wld_result)
    basis = _orthonormal_basis(reachable_directions; tol=tol)
    reachable_projection_matrix = basis * transpose(basis)
    overlap = projection * reachable_projection_matrix
    overlap_norm = norm(overlap)
    ReachabilityResult(
        projection,
        reachable_projection_matrix,
        Float64(overlap_norm),
        overlap_norm > tol,
    )
end

function reachable_world_projection(
    wld_result::WldResult,
    reachable_directions::AbstractVector;
    tol::Real=1e-10,
)
    reachable_world_projection(wld_result, reshape(reachable_directions, :, 1); tol=tol)
end

check_wld_reachable(wld_result::WldResult, reachable_directions; tol::Real=1e-10) =
    reachable_world_projection(wld_result, reachable_directions; tol=tol).reachable
