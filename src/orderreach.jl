using LinearAlgebra

struct FinitePreorder{T,F}
    elements::Vector{T}
    leq::F

    function FinitePreorder(elements::AbstractVector{T}, leq::F) where {T,F}
        length(unique(elements)) == length(elements) ||
            throw(ArgumentError("preorder elements must be unique"))
        new{T,F}(collect(elements), leq)
    end
end

struct OrderedReachabilityResult{T}
    upset::Set{T}
    directions::AbstractMatrix
    reachability::ReachabilityResult
end

struct DirectionMap{F}
    fn::F
end

(map::DirectionMap)(feature) = map.fn(feature)

function _direction_matrix(direction)
    if direction isa AbstractMatrix
        return direction
    elseif direction isa AbstractVector && eltype(direction) <: Real
        return reshape(collect(direction), :, 1)
    end

    columns = [collect(column) for column in direction]
    isempty(columns) && throw(ArgumentError("direction collection must be non-empty"))
    dimension = length(first(columns))
    all(column -> length(column) == dimension, columns) ||
        throw(DimensionMismatch("all mapped directions must have the same dimension"))
    reduce(hcat, columns)
end

function upward_closure(order::FinitePreorder, seeds)
    seed_set = Set(seeds)
    Set(
        element for element in order.elements
        if any(seed -> order.leq(seed, element), seed_set)
    )
end

function downward_closure(order::FinitePreorder, seeds)
    seed_set = Set(seeds)
    Set(
        element for element in order.elements
        if any(seed -> order.leq(element, seed), seed_set)
    )
end

function ordered_reachable_world_projection(
    wld_result::WldResult,
    order::FinitePreorder,
    epsilon,
    direction_map;
    tol::Real=1e-10,
)
    upset = upward_closure(order, epsilon)
    isempty(upset) && throw(ArgumentError("upward closure is empty"))

    mapped = [_direction_matrix(direction_map(element)) for element in order.elements if element in upset]
    isempty(mapped) && throw(ArgumentError("no directions are available for upward closure"))
    dimension = size(first(mapped), 1)
    all(matrix -> size(matrix, 1) == dimension, mapped) ||
        throw(DimensionMismatch("all mapped directions must have the same dimension"))

    directions = reduce(hcat, mapped)
    reachability = reachable_world_projection(wld_result, directions; tol=tol)
    OrderedReachabilityResult(upset, directions, reachability)
end

check_ordered_wld_reachable(args...; kwargs...) =
    ordered_reachable_world_projection(args...; kwargs...).reachability.reachable

function feature_direction_map(tensor::AbstractMatrix; normalize::Bool=true, tol::Real=1e-10)
    DirectionMap(feature_index -> begin
        1 <= feature_index <= size(tensor, 1) ||
            throw(BoundsError(tensor, (feature_index, :)))
        direction = vec(tensor[feature_index, :])
        direction_norm = norm(direction)
        direction_norm <= tol && return zeros(eltype(direction), length(direction))
        normalize ? direction / direction_norm : direction
    end)
end
