using LinearAlgebra

struct UmweltComparison
    world1::WldResult
    world2::WldResult
    projection_distance::Float64
    changed::Bool
end

function compare_umwelt(
    adapter1::SigmaSystemAdapter,
    adapter2::SigmaSystemAdapter,
    action::AbstractVector;
    target::Real=1.0,
    eig_tol::Real=1e-6,
    diff_tol::Real=1e-6,
)
    world1 = system_actuated_world(adapter1, action; target=target, tol=eig_tol)
    world2 = system_actuated_world(adapter2, action; target=target, tol=eig_tol)
    size(world1.loop) == size(world2.loop) ||
        throw(DimensionMismatch("world loop dimensions must match"))
    distance = norm(world_projection(world1) - world_projection(world2))
    UmweltComparison(world1, world2, Float64(distance), distance > diff_tol)
end
