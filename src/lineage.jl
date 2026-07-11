struct FiniteSemanticEquivalence{S,F}
    systems::Vector{S}
    equivalent::F
end

function check_semantic_equivalence(semantics::FiniteSemanticEquivalence)
    systems = semantics.systems
    relation = semantics.equivalent
    reflexive = all(system -> relation(system, system), systems)
    symmetric = all(!relation(left, right) || relation(right, left)
        for left in systems, right in systems)
    transitive = all(
        !(relation(left, middle) && relation(middle, right)) || relation(left, right)
        for left in systems, middle in systems, right in systems
    )
    reflexive && symmetric && transitive
end

struct FiniteLineage{S,F}
    systems::Vector{S}
    generation_event::F

    function FiniteLineage(systems::Vector{S}, generation_event::F) where {S,F}
        isempty(systems) && throw(ArgumentError("a lineage must contain a system"))
        new{S,F}(systems, generation_event)
    end
end

function check_lineage(lineage::FiniteLineage)
    all(index -> lineage.generation_event(
            lineage.systems[index], lineage.systems[index + 1]),
        1:(length(lineage.systems) - 1))
end

"""Bounded observation corresponding to `FreshSem`; not an infinite proof."""
function check_fresh_sem_prefix(
    lineage::FiniteLineage,
    semantics::FiniteSemanticEquivalence;
    start::Integer=1,
)
    check_semantic_equivalence(semantics) || return false
    1 <= start <= length(lineage.systems) ||
        throw(ArgumentError("start is outside the lineage"))
    any(start:length(lineage.systems)) do index
        all(!semantics.equivalent(lineage.systems[index], lineage.systems[prior])
            for prior in 1:(index - 1))
    end
end

function check_eventually_periodic_sem_prefix(
    lineage::FiniteLineage,
    semantics::FiniteSemanticEquivalence;
    start::Integer,
    period::Integer,
)
    period > 0 || throw(ArgumentError("period must be positive"))
    1 <= start <= length(lineage.systems) ||
        throw(ArgumentError("start is outside the lineage"))
    start + period <= length(lineage.systems) ||
        throw(ArgumentError("the observed prefix contains no periodic comparison"))
    all(start:(length(lineage.systems) - period)) do index
        semantics.equivalent(lineage.systems[index + period], lineage.systems[index])
    end
end

function check_cofinal_over_bounds(lineage::FiniteLineage, quantity, bounds)
    all(bound -> any(bound < quantity(system) for system in lineage.systems), bounds)
end

function check_produces_richer_system(
    parent,
    candidate_children,
    generation_event,
    viable,
    quantity,
)
    !viable(parent) || any(
        generation_event(parent, child) && viable(child) &&
            quantity(parent) < quantity(child)
        for child in candidate_children
    )
end
