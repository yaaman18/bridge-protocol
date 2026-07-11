struct BoundaryEdge{S}
    source::S
    target::S
end

function absorbing_complement(all_states, viable_states)
    setdiff(Set(all_states), Set(viable_states))
end

function boundary_edges(all_states, viable_states, successor)
    viable = Set(viable_states)
    complement = absorbing_complement(all_states, viable)
    edges = BoundaryEdge[]
    for state in all_states
        next_state = successor(state)
        if state in viable && next_state in complement
            push!(edges, BoundaryEdge(state, next_state))
        end
    end
    edges
end

function check_absorbing(states, absorbing_set, successor)
    absorbing = Set(absorbing_set)
    all(state -> successor(state) in absorbing, absorbing)
end
