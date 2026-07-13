"""
    check_dc_viable_translation(; step_closed=true, inverse_translation=false)

Runtime audit for the one-way DC-to-OpenSystem translation boundary.
Julia does not certify the Lean construction; it only rejects reports that
claim an inverse viability-to-DC translation.
"""
function check_dc_viable_translation(; step_closed::Bool=true, inverse_translation::Bool=false)
    step_closed && !inverse_translation
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
