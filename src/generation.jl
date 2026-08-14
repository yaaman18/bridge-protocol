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
