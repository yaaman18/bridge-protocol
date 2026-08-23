"""
    check_dc_viable_translation(; step_closed=true, inverse_translation=false)

Runtime audit for the one-way DC-to-OpenSystem translation boundary.
Julia does not certify the Lean construction; it only rejects reports that
claim an inverse viability-to-DC translation.
"""
function check_dc_viable_translation(; step_closed::Bool=true, inverse_translation::Bool=false)
    step_closed && !inverse_translation
end

"""Validate a supplied finite encoding of `dcViableTranslation`."""
function check_dc_viable_translation(
    dc::ERIEState,
    all_M,
    all_E,
    all_C,
    all_S,
    candidate::NamedTuple,
)
    check_DC(dc, all_M, all_E, all_C) || return false
    states_list = collect(all_S)
    length(unique(states_list)) == length(states_list) || return false
    states = Set(states_list)
    dc.s in states || return false
    hasproperty(candidate, :step) || return false
    hasproperty(candidate, :viable) || return false

    configurations = [
        (fast, (slow, environment))
        for fast in states, slow in states, environment in states
    ]
    target = (dc.s, (dc.s, dc.s))
    expected_step = Set([target])

    all(configurations) do configuration
        supplied_step = Set(candidate.step(configuration))
        supplied_step == expected_step || return false
        viable_value = candidate.viable(configuration)
        viable_value isa Bool || return false
        viable_value == (configuration[1] == dc.s) || return false
        !viable_value || all(supplied_step) do successor
            successor_viable = candidate.viable(successor)
            successor_viable isa Bool && successor_viable
        end
    end
end

"""
    check_proliferation_morphism(; parent_viable=true, child_viable=true,
        heritage_lax=true, child_rank_le_wstar=true, phi_rich_lax=true,
        branch_transport=true, inverse_translation=false)

Runtime audit for a proliferation witness.  The Lean side owns the formal
statement; Julia checks that the execution-layer report keeps the witness
one-way and includes the required local premises.
"""
function check_proliferation_morphism(;
    parent_viable::Bool=true,
    child_viable::Bool=true,
    heritage_lax::Bool=true,
    child_rank_le_wstar::Bool=true,
    phi_rich_lax::Bool=true,
    branch_transport::Bool=true,
    inverse_translation::Bool=false,
)
    parent_viable && child_viable && heritage_lax && child_rank_le_wstar &&
        phi_rich_lax && branch_transport && !inverse_translation
end

function _generation_finite_carrier(values)
    items = collect(values)
    length(unique(items)) == length(items) || return nothing
    items
end

function _generation_bool_call(f, args...)
    value = try
        f(args...)
    catch
        return nothing
    end
    value isa Bool ? value : nothing
end

function _generation_phi_rich(dc::ERIEState, motors)::Int
    act = Act(
        dc.structure.rho_rel,
        dc.structure.sigma_rel,
        dc.kappa,
        dc.epsilon,
        dc.s,
    )
    any(motor -> motor in act && is_branch_point(dc.structure.alpha_rel, motor), motors) ? 1 : 0
end

function _proliferation_richness_obligations(
    parent::ERIEState,
    child::ERIEState,
    parent_motors,
    child_motors,
)
    parent_act = Act(
        parent.structure.rho_rel,
        parent.structure.sigma_rel,
        parent.kappa,
        parent.epsilon,
        parent.s,
    )
    child_act = Act(
        child.structure.rho_rel,
        child.structure.sigma_rel,
        child.kappa,
        child.epsilon,
        child.s,
    )
    parent_rich(motor) =
        motor in parent_act && is_branch_point(parent.structure.alpha_rel, motor)
    child_rich(motor) =
        motor in child_act && is_branch_point(child.structure.alpha_rel, motor)

    parent_phi = _generation_phi_rich(parent, parent_motors)
    child_phi = _generation_phi_rich(child, child_motors)
    phi_rich_lax = parent_phi <= child_phi
    branch_transport = all(parent_motors) do motor
        !parent_rich(motor) || any(child_rich, child_motors)
    end
    (; parent_phi, child_phi, phi_rich_lax, branch_transport)
end

"""Validate a complete finite encoding of a `ProliferationMorphism` witness."""
function check_proliferation_morphism(
    parent::ERIEState,
    child::ERIEState,
    parent_carriers::NamedTuple,
    child_carriers::NamedTuple,
    heritage_carrier,
    rank_carrier,
    candidate::NamedTuple,
)::Bool
    carrier_fields = Set((:motors, :environments, :cores, :states))
    Set(propertynames(parent_carriers)) == carrier_fields || return false
    Set(propertynames(child_carriers)) == carrier_fields || return false
    candidate_fields = Set((
        :parent_config,
        :child_config,
        :record,
        :parent_heritage,
        :child_heritage,
        :heritage_related,
        :rank_le,
        :parent_rank,
        :child_rank,
        :wstar,
    ))
    Set(propertynames(candidate)) == candidate_fields || return false

    try
        parent_motors = _generation_finite_carrier(parent_carriers.motors)
        parent_environments = _generation_finite_carrier(parent_carriers.environments)
        parent_cores = _generation_finite_carrier(parent_carriers.cores)
        parent_states = _generation_finite_carrier(parent_carriers.states)
        child_motors = _generation_finite_carrier(child_carriers.motors)
        child_environments = _generation_finite_carrier(child_carriers.environments)
        child_cores = _generation_finite_carrier(child_carriers.cores)
        child_states = _generation_finite_carrier(child_carriers.states)
        heritages = _generation_finite_carrier(heritage_carrier)
        ranks = _generation_finite_carrier(rank_carrier)
        any(isnothing, (
            parent_motors,
            parent_environments,
            parent_cores,
            parent_states,
            child_motors,
            child_environments,
            child_cores,
            child_states,
            heritages,
            ranks,
        )) && return false

        check_DC(parent, parent_motors, parent_environments, parent_cores) || return false
        check_DC(child, child_motors, child_environments, child_cores) || return false
        parent.s in parent_states || return false
        child.s in child_states || return false

        parent_configs = [
            (fast, (slow, environment))
            for fast in parent_states, slow in parent_states, environment in parent_states
        ]
        child_configs = [
            (fast, (slow, environment))
            for fast in child_states, slow in child_states, environment in child_states
        ]
        candidate.parent_config in parent_configs || return false
        candidate.child_config in child_configs || return false

        parent_viable = candidate.parent_config[1] == parent.s
        child_viable = candidate.child_config[1] == child.s
        parent_viable || return false
        child_viable || return false

        parent_heritage_values = Dict{Any,Any}()
        for configuration in parent_configs
            value = candidate.parent_heritage(configuration)
            value in heritages || return false
            parent_heritage_values[configuration] = value
        end
        child_heritage_values = Dict{Any,Any}()
        for configuration in child_configs
            value = candidate.child_heritage(configuration)
            value in heritages || return false
            child_heritage_values[configuration] = value
        end
        heritage_relation = Dict{Tuple{Any,Any},Bool}()
        for left in heritages, right in heritages
            related = _generation_bool_call(candidate.heritage_related, left, right)
            related === nothing && return false
            heritage_relation[(left, right)] = related
        end
        heritage_relation[(
            parent_heritage_values[candidate.parent_config],
            child_heritage_values[candidate.child_config],
        )] || return false

        candidate.parent_rank in ranks || return false
        candidate.child_rank in ranks || return false
        candidate.wstar in ranks || return false
        rank_le = Dict{Tuple{Any,Any},Bool}()
        for left in ranks, right in ranks
            le_value = _generation_bool_call(candidate.rank_le, left, right)
            le_value === nothing && return false
            rank_le[(left, right)] = le_value
        end
        all(rank -> rank_le[(rank, rank)], ranks) || return false
        all(
            !rank_le[(left, middle)] || !rank_le[(middle, right)] ||
                rank_le[(left, right)]
            for left in ranks, middle in ranks, right in ranks
        ) || return false
        rank_le[(candidate.child_rank, candidate.wstar)] || return false

        richness = _proliferation_richness_obligations(
            parent,
            child,
            parent_motors,
            child_motors,
        )
        richness.phi_rich_lax || return false
        richness.branch_transport || return false
        true
    catch
        false
    end
end

"""
    check_lineage_stays_open(; cofinal=true, semantic_invariant=true,
        phi_rich_fixed=true,
        asserts_eventual_periodicity=false)

Runtime audit for the lineage openness theorem boundary.
"""
function check_lineage_stays_open(;
    cofinal::Bool=true,
    semantic_invariant::Bool=true,
    phi_rich_fixed::Bool=true,
    asserts_eventual_periodicity::Bool=false,
)
    cofinal && semantic_invariant && phi_rich_fixed && !asserts_eventual_periodicity
end

"""
    check_richness_inherits_generational(; proliferation_morphism=true,
        parent_branch=true, child_branch_transport=true, child_pump=true,
        phi_rich_lax=true)

Runtime audit for lifting the single-step richness pump through a generation
witness.
"""
function check_richness_inherits_generational(;
    proliferation_morphism::Bool=true,
    parent_branch::Bool=true,
    child_branch_transport::Bool=true,
    child_pump::Bool=true,
    phi_rich_lax::Bool=true,
)
    proliferation_morphism && parent_branch && child_branch_transport && child_pump && phi_rich_lax
end

"""Validate the `phi_rich_lax` field of a supplied finite-value witness."""
function check_richness_inherits_generational(
    parent_phi,
    child_phi;
    proliferation_morphism::Bool=true,
    phi_rich_lax::Bool=true,
)
    inequality_holds = parent_phi <= child_phi
    field_valid = phi_rich_lax && inequality_holds
    (
        proliferation_morphism=proliferation_morphism,
        inequality_holds=inequality_holds,
        phi_rich_lax=phi_rich_lax,
        field_valid=field_valid,
        contract_holds=proliferation_morphism && field_valid,
    )
end

"""
    check_rich_lineage_cofinal(N, bound;
        step_certificates=fill(true, N), scores=collect(1:(N + 1)),
        semantic_invariant=true)

Check the executable finite-prefix boundary for VP-GEN-005.  The checker
requires one proliferation certificate for every adjacent pair in generations
`0:N`, the reference score law `score(n) = n + 1`, semantic invariance of the
reported score, and a generation whose score exceeds `bound`.

This finite audit does not claim to prove the infinite cofinality theorem; that
claim belongs to Lean.
"""
function check_rich_lineage_cofinal(
    N::Integer,
    bound::Integer;
    step_certificates=fill(true, N),
    scores=collect(1:(N + 1)),
    semantic_invariant::Bool=true,
)
    N >= 0 || throw(ArgumentError("N must be nonnegative"))
    bound >= 0 || throw(ArgumentError("bound must be nonnegative"))
    length(step_certificates) == N || return false
    length(scores) == N + 1 || return false

    all(step_certificates) &&
        semantic_invariant &&
        all(n -> scores[n + 1] == n + 1, 0:N) &&
        any(score -> bound < score, scores)
end

"""
    check_branched_rich_lineage_cofinal(N, bound; ...)

Finite-prefix audit for VP-GEN-006. In addition to the GEN-005 score law and
cofinal witness, every generation must carry a branch and every adjacent step
must carry a non-vacuous branch-transport certificate.
"""
function check_branched_rich_lineage_cofinal(
    N::Integer,
    bound::Integer;
    step_certificates=fill(true, N),
    branch_witnesses=fill(true, N + 1),
    branch_transports=fill(true, N),
    scores=collect(1:(N + 1)),
    semantic_invariant::Bool=true,
)
    N >= 0 || throw(ArgumentError("N must be nonnegative"))
    bound >= 0 || throw(ArgumentError("bound must be nonnegative"))
    length(step_certificates) == N || return false
    length(branch_witnesses) == N + 1 || return false
    length(branch_transports) == N || return false
    length(scores) == N + 1 || return false

    all(step_certificates) &&
        all(branch_witnesses) &&
        all(branch_transports) &&
        semantic_invariant &&
        all(n -> scores[n + 1] == n + 1, 0:N) &&
        any(score -> bound < score, scores)
end
