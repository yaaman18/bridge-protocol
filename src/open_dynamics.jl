abstract type OpenEdgeKind end

struct InternalEdge <: OpenEdgeKind end

struct CouplingEdge{P} <: OpenEdgeKind
    port::P
end

const INTERNAL_EDGE = InternalEdge()

struct FiniteOpenGraph{S,F}
    states::Vector{S}
    step::F

    function FiniteOpenGraph(states::AbstractVector{S}, step::F) where {S,F}
        length(unique(states)) == length(states) ||
            throw(ArgumentError("open graph states must be unique"))
        new{S,F}(collect(states), step)
    end
end

FiniteOpenGraph(step::F, states::AbstractVector{S}) where {S,F} =
    FiniteOpenGraph(states, step)

struct OpenPath{S,K<:OpenEdgeKind}
    states::Vector{S}
    kinds::Vector{K}

    function OpenPath(states::AbstractVector{S}, kinds::AbstractVector{K}) where {S,K<:OpenEdgeKind}
        isempty(states) && throw(ArgumentError("a path must contain its initial state"))
        length(kinds) + 1 == length(states) ||
            throw(ArgumentError("path kinds must have length states-1"))
        new{S,K}(collect(states), collect(kinds))
    end
end

path_length(path::OpenPath) = length(path.kinds)
internal_path(path::OpenPath) = all(kind -> kind isa InternalEdge, path.kinds)

function check_open_path(graph::FiniteOpenGraph, path::OpenPath)
    all(state -> state in graph.states, path.states) || return false
    all(eachindex(path.kinds)) do index
        graph.step(path.states[index], path.kinds[index], path.states[index + 1])
    end
end

struct FiniteOpenFrame{G,FI,FA,FB,FF}
    graph::G
    init::FI
    admissible::FA
    envelope::FB
    fair_lasso::FF

    function FiniteOpenFrame(
        graph::G,
        init::FI,
        admissible::FA,
        envelope::FB,
        fair_lasso::FF=(lasso -> true),
    ) where {G,FI,FA,FB,FF}
        all(!admissible(state) || envelope(state) for state in graph.states) ||
            throw(ArgumentError("admissible states must be inside the recovery envelope"))
        new{G,FI,FA,FB,FF}(graph, init, admissible, envelope, fair_lasso)
    end
end

function _adjacency(graph::FiniteOpenGraph; internal_only::Bool=false)
    count = length(graph.states)
    adjacency = falses(count, count)
    for source in 1:count, target in 1:count
        if internal_only
            adjacency[source, target] =
                graph.step(graph.states[source], INTERNAL_EDGE, graph.states[target])
        else
            adjacency[source, target] =
                graph.step(graph.states[source], INTERNAL_EDGE, graph.states[target])
            # Coupling ports cannot be inferred from a predicate. Callers that need
            # finite closure supply the explicit edge alphabet overload below.
        end
    end
    adjacency
end

function _adjacency(graph::FiniteOpenGraph, edge_kinds::AbstractVector{<:OpenEdgeKind})
    count = length(graph.states)
    adjacency = falses(count, count)
    for source in 1:count, target in 1:count
        adjacency[source, target] = any(
            kind -> graph.step(graph.states[source], kind, graph.states[target]),
            edge_kinds,
        )
    end
    adjacency
end

function _positive_transitive_closure(adjacency::BitMatrix)
    closure = copy(adjacency)
    count = size(closure, 1)
    for pivot in 1:count, source in 1:count, target in 1:count
        closure[source, target] |= closure[source, pivot] && closure[pivot, target]
    end
    closure
end

function _reflexive_closure(positive::BitMatrix)
    closure = copy(positive)
    for index in axes(closure, 1)
        closure[index, index] = true
    end
    closure
end

"""Decide FIH for a finite graph. `horizon=n` is a valid uniform bound.

This is the finite-model decision procedure for the Lean predicate; it does not
claim to decide FIH for arbitrary or implicit state spaces.
"""
function check_finite_internal_horizon(frame::FiniteOpenFrame)
    graph = frame.graph
    count = length(graph.states)
    positive = _positive_transitive_closure(_adjacency(graph; internal_only=true))
    admissible = map(frame.admissible, graph.states)
    for source in eachindex(graph.states)
        admissible[source] || continue
        for cycle in eachindex(graph.states)
            reachable_cycle = source == cycle || positive[source, cycle]
            positive[cycle, cycle] || continue
            reaches_admissible = any(
                admissible[target] && (cycle == target || positive[cycle, target])
                for target in eachindex(graph.states)
            )
            if reachable_cycle && reaches_admissible
                return (holds=false, horizon=nothing, violating_state=graph.states[source])
            end
        end
    end
    (holds=true, horizon=count, violating_state=nothing)
end

function check_recoverable(
    frame::FiniteOpenFrame,
    edge_kinds::AbstractVector{<:OpenEdgeKind},
)
    closure = _reflexive_closure(
        _positive_transitive_closure(_adjacency(frame.graph, edge_kinds)),
    )
    admissible = map(frame.admissible, frame.graph.states)
    all(eachindex(frame.graph.states)) do source
        !frame.envelope(frame.graph.states[source]) ||
            any(admissible[target] && closure[source, target] for target in eachindex(admissible))
    end
end

function check_no_terminal_init(
    frame::FiniteOpenFrame,
    edge_kinds::AbstractVector{<:OpenEdgeKind},
)
    closure = _reflexive_closure(
        _positive_transitive_closure(_adjacency(frame.graph, edge_kinds)),
    )
    initial = findall(state -> frame.init(state), frame.graph.states)
    reachable = [
        target for target in eachindex(frame.graph.states)
        if any(closure[source, target] for source in initial)
    ]
    !any(target -> all(source -> closure[source, target], reachable), reachable)
end

function check_possible_live(
    frame::FiniteOpenFrame,
    edge_kinds::AbstractVector{<:OpenEdgeKind},
)
    positive = _positive_transitive_closure(_adjacency(frame.graph, edge_kinds))
    initial = findall(state -> frame.init(state), frame.graph.states)
    any(eachindex(frame.graph.states)) do admissible_index
        frame.admissible(frame.graph.states[admissible_index]) || return false
        positive[admissible_index, admissible_index] || return false
        any(source == admissible_index || positive[source, admissible_index] for source in initial)
    end
end

struct FiniteLassoExecution{S,K<:OpenEdgeKind}
    states::Vector{S}
    kinds::Vector{K}
    loop_start::Int

    function FiniteLassoExecution(
        states::AbstractVector{S},
        kinds::AbstractVector{K},
        loop_start::Integer,
    ) where {S,K<:OpenEdgeKind}
        isempty(states) && throw(ArgumentError("lasso must contain a state"))
        length(kinds) == length(states) ||
            throw(ArgumentError("lasso needs one outgoing edge kind per state"))
        1 <= loop_start <= length(states) ||
            throw(ArgumentError("loop_start is outside the lasso"))
        new{S,K}(collect(states), collect(kinds), Int(loop_start))
    end
end

function check_lasso(graph::FiniteOpenGraph, lasso::FiniteLassoExecution)
    all(state -> state in graph.states, lasso.states) || return false
    all(eachindex(lasso.states)) do index
        successor = index == length(lasso.states) ? lasso.loop_start : index + 1
        graph.step(lasso.states[index], lasso.kinds[index], lasso.states[successor])
    end
end

function check_recurrent_lasso(frame::FiniteOpenFrame, lasso::FiniteLassoExecution)
    check_lasso(frame.graph, lasso) || return false
    any(frame.admissible, lasso.states[lasso.loop_start:end])
end

function check_fair_lasso_live(
    frame::FiniteOpenFrame,
    lassos::AbstractVector{<:FiniteLassoExecution},
)
    fair = [lasso for lasso in lassos if frame.fair_lasso(lasso)]
    !isempty(fair) && all(lasso -> check_recurrent_lasso(frame, lasso), fair)
end
