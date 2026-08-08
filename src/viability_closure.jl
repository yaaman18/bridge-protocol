"""Reflexive one-step closure of a finite state subset."""
function successor_closure(states, step, subset)
    closed = Set(subset)
    for source in subset, target in states
        step(source, target) && push!(closed, target)
    end
    closed
end

"""Check the finite realization of the A-2 viability-to-closure object map."""
function check_viability_closure(states, step, viable)
    viable_states = Set(state for state in states if viable(state))
    closed = successor_closure(states, step, viable_states)
    step_closed = all(
        !viable(source) || !step(source, target) || viable(target)
        for source in states for target in states
    )
    postfixed = issubset(viable_states, closed)
    fixed = closed == viable_states
    (
        viable_states=viable_states,
        closure=closed,
        step_closed=step_closed,
        left_postfixed=postfixed,
        right_postfixed=postfixed,
        fixed=fixed,
        invariant_implies_fixed=!step_closed || fixed,
        contract_premises=step_closed,
        contract_conclusion=fixed,
        contract_holds=step_closed && fixed,
    )
end

"""Check naturality of viability stages and successor closure under a finite renaming."""
function check_viability_closure_naturality(
    source_states,
    target_states,
    mapping,
    source_step,
    target_step,
    source_viable,
    target_viable,
)
    mapped(values) = Set(mapping[value] for value in values)
    source_viable_set = Set(state for state in source_states if source_viable(state))
    target_viable_set = Set(state for state in target_states if target_viable(state))
    source_closed = successor_closure(source_states, source_step, source_viable_set)
    target_closed = successor_closure(target_states, target_step, target_viable_set)
    bijective = Set(keys(mapping)) == Set(source_states) &&
        Set(values(mapping)) == Set(target_states)
    step_preserved = all(
        source_step(source, target) == target_step(mapping[source], mapping[target])
        for source in source_states for target in source_states
    )
    viability_preserved = all(
        source_viable(source) == target_viable(mapping[source])
        for source in source_states
    )
    premises = bijective && step_preserved && viability_preserved
    left_natural = mapped(source_closed) == target_closed
    (
        bijective=bijective,
        step_preserved=step_preserved,
        viability_preserved=viability_preserved,
        stage_natural=mapped(source_viable_set) == target_viable_set,
        left_natural=left_natural,
        right_natural=mapped(source_closed) == target_closed,
        contract_premises=premises,
        contract_conclusion=left_natural,
        contract_holds=premises && left_natural,
    )
end

"""Decide closure naturality for every explicitly enumerated finite subset `K`."""
function check_viability_closure_naturality(
    source_states,
    target_states,
    mapping,
    source_step,
    target_step,
    source_viable,
    target_viable,
    source_subsets,
)
    mapped(values) = Set(mapping[value] for value in values)
    subsets = [Set(subset) for subset in source_subsets]
    expected_subsets = powerset(Set(source_states))
    subset_family_complete = Set(subsets) == Set(expected_subsets)
    subsets_in_carrier = all(subset -> subset ⊆ Set(source_states), subsets)
    bijective = Set(keys(mapping)) == Set(source_states) &&
        Set(values(mapping)) == Set(target_states)
    step_preserved = all(
        source_step(source, target) == target_step(mapping[source], mapping[target])
        for source in source_states for target in source_states
    )
    viability_preserved = all(
        source_viable(source) == target_viable(mapping[source])
        for source in source_states
    )
    premises = subset_family_complete && subsets_in_carrier && bijective &&
        step_preserved && viability_preserved
    subset_natural = all(subsets) do subset
        mapped(successor_closure(source_states, source_step, subset)) ==
            successor_closure(target_states, target_step, mapped(subset))
    end
    (
        bijective=bijective,
        step_preserved=step_preserved,
        viability_preserved=viability_preserved,
        subset_family_complete=subset_family_complete,
        subsets_in_carrier=subsets_in_carrier,
        subset_natural=subset_natural,
        left_natural=subset_natural,
        right_natural=subset_natural,
        contract_premises=premises,
        contract_conclusion=subset_natural,
        contract_holds=premises && subset_natural,
    )
end

"""Realize the two viability closures by explicit pi/rho/alpha/sigma relations."""
function check_viability_relational_frame(states, step, viable)
    identity_rel = state -> Set([state])
    reflexive_step_rel = source -> Set(
        target for target in states if target == source || step(source, target)
    )
    viable_states = Set(state for state in states if viable(state))
    abstract_closure = successor_closure(states, step, viable_states)
    left_closure = Phi(identity_rel, reflexive_step_rel, viable_states)
    right_closure = T_prime(identity_rel, reflexive_step_rel, viable_states)
    step_closed = all(
        !viable(source) || !step(source, target) || viable(target)
        for source in states for target in states
    )
    left_fixed = left_closure == viable_states
    (
        viable_states=viable_states,
        abstract_closure=abstract_closure,
        left_closure=left_closure,
        right_closure=right_closure,
        left_realizes=left_closure == abstract_closure,
        right_realizes=right_closure == abstract_closure,
        left_postfixed=issubset(viable_states, left_closure),
        right_postfixed=issubset(viable_states, right_closure),
        left_fixed=left_fixed,
        contract_premises=step_closed,
        contract_conclusion=left_fixed,
        contract_holds=step_closed && left_fixed,
    )
end

"""Check preservation of all six fields of the explicit relational frame."""
function check_viability_relational_functor(
    source_states,
    target_states,
    mapping,
    source_step,
    target_step,
    source_viable,
    target_viable,
)
    identity_preserved = all(
        (source_target == source) == (mapping[source_target] == mapping[source])
        for source in source_states for source_target in source_states
    )
    reflexive_step_preserved = all(
        (source_target == source || source_step(source, source_target)) ==
            (mapping[source_target] == mapping[source] ||
             target_step(mapping[source], mapping[source_target]))
        for source in source_states for source_target in source_states
    )
    viability_preserved = all(
        source_viable(source) == target_viable(mapping[source])
        for source in source_states
    )
    bijective = Set(keys(mapping)) == Set(source_states) &&
        Set(values(mapping)) == Set(target_states)
    structural_premises = bijective && identity_preserved && reflexive_step_preserved
    frame_iso = structural_premises && viability_preserved
    (
        bijective=bijective,
        pi_preserved=identity_preserved,
        rho_preserved=reflexive_step_preserved,
        alpha_preserved=identity_preserved,
        sigma_preserved=reflexive_step_preserved,
        kappa_preserved=viability_preserved,
        epsilon_preserved=viability_preserved,
        frame_iso=frame_iso,
        contract_premises=structural_premises,
        contract_conclusion=viability_preserved,
        contract_holds=structural_premises && viability_preserved,
    )
end
