using LinearAlgebra

struct ToyRecurrentSystem{A<:AbstractMatrix,B<:AbstractMatrix}
    recurrent::A
    action_map::B

    function ToyRecurrentSystem(recurrent::A, action_map::B) where {A<:AbstractMatrix,B<:AbstractMatrix}
        size(recurrent, 1) == size(recurrent, 2) ||
            throw(DimensionMismatch("recurrent matrix must be square"))
        size(action_map, 1) == size(recurrent, 1) ||
            throw(DimensionMismatch("action_map row count must match recurrent dimension"))
        new{A,B}(recurrent, action_map)
    end
end

function toy_recurrent_step(system::ToyRecurrentSystem, state::AbstractVector, action::AbstractVector)
    length(state) == size(system.recurrent, 2) ||
        throw(DimensionMismatch("state length must match recurrent dimension"))
    length(action) == size(system.action_map, 2) ||
        throw(DimensionMismatch("action length must match action dimension"))
    tanh.(system.recurrent * state + system.action_map * action)
end

function toy_recurrent_features(state::AbstractVector)
    isempty(state) && throw(ArgumentError("state must be non-empty"))
    [
        sum(state) / length(state),
        sum(abs2, state),
        first(state),
        last(state),
    ]
end

function toy_recurrent_adapter(system::ToyRecurrentSystem, initial_state::AbstractVector)
    SigmaSystemAdapter(
        copy(initial_state),
        (state, action) -> toy_recurrent_step(system, state, action),
        toy_recurrent_features,
    )
end
