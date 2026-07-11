"""Check a finite collapse witness and one-step permanence of the empty core."""
function check_finite_collapse(update, intrinsic, initial; max_steps::Integer)
    max_steps >= 0 || throw(ArgumentError("max_steps must be nonnegative"))
    state = initial
    for step in 0:max_steps
        if isempty(intrinsic(state))
            return isempty(intrinsic(update(state)))
        end
        step == max_steps || (state = update(state))
    end
    false
end

function finite_update(phi, theta, drift, configuration)
    (
        kappa=intersect(Set(configuration.kappa), Set(phi(configuration.rank, configuration.kappa))),
        epsilon=intersect(
            Set(configuration.epsilon),
            Set(theta(configuration.rank, configuration.epsilon)),
        ),
        rank=drift(configuration.rank, configuration.kappa),
    )
end

struct FiniteTotalNext{S,F,G}
    states::Vector{S}
    next::F
    step_internal::G
end

function check_total_next(total::FiniteTotalNext)
    state_set = Set(total.states)
    length(state_set) == length(total.states) || return false
    all(total.states) do state
        successor = total.next(state)
        successor in state_set && total.step_internal(state, successor)
    end
end

function total_orbit_prefix(total::FiniteTotalNext, initial, steps::Integer)
    steps >= 0 || throw(ArgumentError("steps must be nonnegative"))
    check_total_next(total) || throw(ArgumentError("invalid TotalNext witness"))
    initial in Set(total.states) || throw(ArgumentError("initial state is outside carrier"))
    orbit = [initial]
    for _ in 1:steps
        push!(orbit, total.next(last(orbit)))
    end
    orbit
end

function finite_reachable(states, step, source, target)
    state_set = Set(states)
    source in state_set && target in state_set || return false
    frontier = [source]
    visited = Set([source])
    while !isempty(frontier)
        current = popfirst!(frontier)
        current == target && return true
        for candidate in states
            if !(candidate in visited) && step(current, candidate)
                push!(visited, candidate)
                push!(frontier, candidate)
            end
        end
    end
    false
end

function down_to_viable(states, viable_states, step)
    viable = Set(viable_states)
    Set(
        state for state in states
        if any(target -> finite_reachable(states, step, state, target), viable)
    )
end

function check_k_absorbing(states, viable_states, step)
    down = down_to_viable(states, viable_states, step)
    region = setdiff(Set(states), down)
    all(source in region for source in region) || return false
    all(
        !step(source, target) || target in region
        for source in region for target in states
    )
end

function finite_boundary_pairs(states, viable_states, step)
    down = down_to_viable(states, viable_states, step)
    region = setdiff(Set(states), down)
    [
        (source=source, target=target)
        for source in states for target in states
        if source in down && step(source, target) && target in region
    ]
end

check_boundary_oneway(states, viable_states, step) =
    check_k_absorbing(states, viable_states, step)

function check_ins_mixed_fiber(states, region_states, observe)
    region = Set(region_states)
    any(
        inside in region && !(outside in region) && observe(inside) == observe(outside)
        for inside in states for outside in states
    )
end
