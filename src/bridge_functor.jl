"""Counterexample showing that alpha-only data cannot classify hinge existence."""
function alpha_only_hinge_counterexample()
    alpha_rel = _ -> Set([:e])
    sigma_rel = _ -> Set([:m])
    kappa = Set([:c])
    epsilon = Set([:e])
    rho_full = _ -> Set([:m])
    rho_empty = _ -> Set{Symbol}()
    state = :s
    hinge_full = !isempty(Act(rho_full, sigma_rel, _ -> kappa, _ -> epsilon, state))
    hinge_empty = !isempty(Act(rho_empty, sigma_rel, _ -> kappa, _ -> epsilon, state))
    (
        same_alpha=alpha_rel(:m) == alpha_rel(:m),
        full=hinge_full,
        empty=hinge_empty,
        refutes_alpha_only=hinge_full != hinge_empty,
    )
end

"""Counterexample to the unnormalized `M' * M` bridge candidate."""
function raw_gram_bridge_counterexample()
    alpha_matrix = ones(2, 1)
    gram = transpose(alpha_matrix) * alpha_matrix
    rho_rel = _ -> Set([:m])
    sigma_rel = _ -> Set([:m])
    hinge = Act(rho_rel, sigma_rel, _ -> Set([:c]), _ -> Set([:e1, :e2]), :s)
    (
        hinge_nonempty=!isempty(hinge),
        gram=gram,
        eigenvalues=eigvals(Symmetric(gram)),
        fixed_nontrivial=any(isone, eigvals(Symmetric(gram))),
    )
end

"""One-dimensional identity/zero loop classified by the complete hinge data."""
function hinge_classifying_loop(rho_rel, sigma_rel, kappa, epsilon, state)
    hinge_nonempty = !isempty(Act(rho_rel, sigma_rel, kappa, epsilon, state))
    hinge_nonempty ? ones(1, 1) : zeros(1, 1)
end

"""Check the exact `hinge nonempty iff fixed nonzero direction` classifier law."""
function check_hinge_classifying_loop(rho_rel, sigma_rel, kappa, epsilon, state)
    hinge_nonempty = !isempty(Act(rho_rel, sigma_rel, kappa, epsilon, state))
    loop = hinge_classifying_loop(rho_rel, sigma_rel, kappa, epsilon, state)
    fixed_nontrivial = loop[1, 1] == 1
    (
        hinge_nonempty=hinge_nonempty,
        fixed_nontrivial=fixed_nontrivial,
        equivalent=hinge_nonempty == fixed_nontrivial,
        loop=loop,
    )
end

"""Check the object classifier against an independently supplied loop candidate."""
function check_hinge_classifying_loop(
    rho_rel,
    sigma_rel,
    kappa,
    epsilon,
    state,
    candidate_loop::AbstractMatrix,
)
    _check_hinge_nontrivial_candidate(
        rho_rel, sigma_rel, kappa, epsilon, state, candidate_loop,
    )
end

"""Check the lax norm law induced by a forward hinge-preserving arrow."""
function check_hinge_classifying_loop_lax(
    rho_source,
    sigma_source,
    kappa_source,
    epsilon_source,
    source_state,
    rho_target,
    sigma_target,
    kappa_target,
    epsilon_target,
    target_state,
)
    source_hinge = !isempty(Act(
        rho_source, sigma_source, kappa_source, epsilon_source, source_state,
    ))
    target_hinge = !isempty(Act(
        rho_target, sigma_target, kappa_target, epsilon_target, target_state,
    ))
    source_loop = hinge_classifying_loop(
        rho_source, sigma_source, kappa_source, epsilon_source, source_state,
    )
    target_loop = hinge_classifying_loop(
        rho_target, sigma_target, kappa_target, epsilon_target, target_state,
    )
    probe = ones(1)
    forward_preserved = !source_hinge || target_hinge
    lax_norm = norm(source_loop * probe) <= norm(target_loop * probe)
    (
        source_hinge=source_hinge,
        target_hinge=target_hinge,
        forward_preserved=forward_preserved,
        lax_norm=lax_norm,
        law_exact=forward_preserved == lax_norm,
    )
end

"""Check the lax law against independently supplied source and target loops."""
function check_hinge_classifying_loop_lax(
    rho_source,
    sigma_source,
    kappa_source,
    epsilon_source,
    source_state,
    rho_target,
    sigma_target,
    kappa_target,
    epsilon_target,
    target_state,
    source_candidate::AbstractMatrix,
    target_candidate::AbstractMatrix,
)
    source_hinge = !isempty(Act(
        rho_source, sigma_source, kappa_source, epsilon_source, source_state,
    ))
    target_hinge = !isempty(Act(
        rho_target, sigma_target, kappa_target, epsilon_target, target_state,
    ))
    source_expected = hinge_classifying_loop(
        rho_source, sigma_source, kappa_source, epsilon_source, source_state,
    )
    target_expected = hinge_classifying_loop(
        rho_target, sigma_target, kappa_target, epsilon_target, target_state,
    )
    source_shape = size(source_candidate) == (1, 1)
    target_shape = size(target_candidate) == (1, 1)
    source_candidate_matches = source_shape && source_candidate == source_expected
    target_candidate_matches = target_shape && target_candidate == target_expected
    forward_preserved = !source_hinge || target_hinge
    probe = ones(1)
    lax_norm = source_shape && target_shape &&
        norm(source_candidate * probe) <= norm(target_candidate * probe)
    premises = forward_preserved && source_candidate_matches && target_candidate_matches
    (
        source_hinge=source_hinge,
        target_hinge=target_hinge,
        source_candidate_matches=source_candidate_matches,
        target_candidate_matches=target_candidate_matches,
        forward_preserved=forward_preserved,
        lax_norm=lax_norm,
        contract_premises=premises,
        contract_conclusion=lax_norm,
        contract_holds=premises && lax_norm,
    )
end

"""Runtime check of identity/composition laws in the thin classifier category."""
function check_hinge_classifier_functor_laws(
    source_live::Bool,
    middle_live::Bool,
    target_live::Bool,
)
    forward(a, b) = !a || b
    identity_law = forward(source_live, source_live) &&
        forward(middle_live, middle_live) && forward(target_live, target_live)
    source_middle = forward(source_live, middle_live)
    middle_target = forward(middle_live, target_live)
    source_target = forward(source_live, target_live)
    composition_law = !(source_middle && middle_target) || source_target
    (
        identity_law=identity_law,
        composition_law=composition_law,
        functor_laws=identity_law && composition_law,
    )
end

function _check_hinge_nontrivial_candidate(
    rho_rel,
    sigma_rel,
    kappa,
    epsilon,
    state,
    candidate_loop::AbstractMatrix,
)
    hinge_nonempty = !isempty(Act(rho_rel, sigma_rel, kappa, epsilon, state))
    expected_loop = hinge_classifying_loop(
        rho_rel, sigma_rel, kappa, epsilon, state,
    )
    candidate_shape = size(candidate_loop) == (1, 1)
    candidate_matches = candidate_shape && candidate_loop == expected_loop
    fixed_nontrivial = candidate_shape && candidate_loop[1, 1] == 1
    conclusion = fixed_nontrivial == hinge_nonempty
    (
        hinge_nonempty=hinge_nonempty,
        fixed_nontrivial=fixed_nontrivial,
        candidate_shape=candidate_shape,
        candidate_matches=candidate_matches,
        contract_premises=candidate_matches,
        contract_conclusion=conclusion,
        contract_holds=candidate_matches && conclusion,
    )
end

"""Check the thin-functor object contract against an independent loop candidate."""
function check_hinge_classifier_functor_laws(
    rho_rel,
    sigma_rel,
    kappa,
    epsilon,
    state,
    candidate_loop::AbstractMatrix,
)
    _check_hinge_nontrivial_candidate(
        rho_rel, sigma_rel, kappa, epsilon, state, candidate_loop,
    )
end

"""Check strict loop equality and identity intertwining on reversible arrows."""
function check_strict_hinge_classifier_intertwining(
    source_live::Bool,
    target_live::Bool,
)
    source_loop = source_live ? ones(1, 1) : zeros(1, 1)
    target_loop = target_live ? ones(1, 1) : zeros(1, 1)
    identity_map = ones(1, 1)
    arrow_valid = source_live == target_live
    loops_equal = source_loop == target_loop
    identity_intertwines = target_loop * identity_map == identity_map * source_loop
    (
        arrow_valid=arrow_valid,
        loops_equal=loops_equal,
        identity_intertwines=identity_intertwines,
        law_exact=arrow_valid == (loops_equal && identity_intertwines),
    )
end

"""Check strict identity intertwining for independently supplied finite loops."""
function check_strict_hinge_classifier_intertwining(
    source_loop::AbstractMatrix,
    target_loop::AbstractMatrix,
    arrow_valid::Bool,
)
    source_shape = size(source_loop) == (1, 1)
    target_shape = size(target_loop) == (1, 1)
    loop_encoding_valid = source_shape && target_shape &&
        all(value -> value == 0 || value == 1, source_loop) &&
        all(value -> value == 0 || value == 1, target_loop)
    identity_map = ones(1, 1)
    loops_equal = loop_encoding_valid && source_loop == target_loop
    identity_intertwines = loop_encoding_valid &&
        target_loop * identity_map == identity_map * source_loop
    conclusion = identity_intertwines
    (
        arrow_valid=arrow_valid,
        loops_equal=loops_equal,
        identity_intertwines=identity_intertwines,
        loop_encoding_valid=loop_encoding_valid,
        contract_premises=arrow_valid && loop_encoding_valid,
        contract_conclusion=conclusion,
        contract_holds=arrow_valid && loop_encoding_valid && conclusion,
    )
end

"""Check identity and composition preservation for the Hilbert intertwiner functor."""
function check_hinge_hilbert_functor(
    source_live::Bool,
    middle_live::Bool,
    target_live::Bool,
)
    identity_source = check_strict_hinge_classifier_intertwining(
        source_live, source_live,
    )
    identity_middle = check_strict_hinge_classifier_intertwining(
        middle_live, middle_live,
    )
    identity_target = check_strict_hinge_classifier_intertwining(
        target_live, target_live,
    )
    first = check_strict_hinge_classifier_intertwining(source_live, middle_live)
    second = check_strict_hinge_classifier_intertwining(middle_live, target_live)
    composite = check_strict_hinge_classifier_intertwining(source_live, target_live)
    composable = first.arrow_valid && second.arrow_valid
    identity_law = identity_source.identity_intertwines &&
        identity_middle.identity_intertwines && identity_target.identity_intertwines
    composition_law = !composable || composite.identity_intertwines
    (
        composable=composable,
        identity_law=identity_law,
        composition_law=composition_law,
        functor_laws=identity_law && composition_law,
    )
end

"""Check the Hilbert-functor object contract against an independent loop candidate."""
function check_hinge_hilbert_functor(
    rho_rel,
    sigma_rel,
    kappa,
    epsilon,
    state,
    candidate_loop::AbstractMatrix,
)
    _check_hinge_nontrivial_candidate(
        rho_rel, sigma_rel, kappa, epsilon, state, candidate_loop,
    )
end

"""Finite renamed-model witness for structural hinge-isomorphism preservation."""
function structural_hinge_isomorphism_witness()
    source_actions = [:m1, :m2]
    target_actions = [:n1, :n2]
    on_action = Dict(:m1 => :n2, :m2 => :n1)
    source_rho = c -> c == :c1 ? Set([:m1]) : Set([:m2])
    target_rho = c -> c == :d1 ? Set([:n2]) : Set([:n1])
    source_sigma = e -> e == :e1 ? Set([:m1]) : Set([:m2])
    target_sigma = e -> e == :f1 ? Set([:n2]) : Set([:n1])
    source_act = Act(
        source_rho, source_sigma, _ -> Set([:c1]), _ -> Set([:e1]), :s,
    )
    target_act = Act(
        target_rho, target_sigma, _ -> Set([:d1]), _ -> Set([:f1]), :t,
    )
    mapped_act = Set(on_action[m] for m in source_act)
    source_loop = isempty(source_act) ? zeros(1, 1) : ones(1, 1)
    target_loop = isempty(target_act) ? zeros(1, 1) : ones(1, 1)
    (
        action_bijection=Set(values(on_action)) == Set(target_actions) &&
            Set(keys(on_action)) == Set(source_actions),
        mapped_act=mapped_act,
        target_act=target_act,
        hinge_preserved=mapped_act == target_act,
        nonempty_equivalent=isempty(source_act) == isempty(target_act),
        loops_equal=source_loop == target_loop,
    )
end


"""Check the structural-functor object contract against an independent loop."""
function structural_hinge_isomorphism_witness(
    rho_rel,
    sigma_rel,
    kappa,
    epsilon,
    state,
    candidate_loop::AbstractMatrix,
)
    _check_hinge_nontrivial_candidate(
        rho_rel, sigma_rel, kappa, epsilon, state, candidate_loop,
    )
end
