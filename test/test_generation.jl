using Test
using ERIEC

@testset "generation boundary audits" begin
    @test check_dc_viable_translation()
    @test !check_dc_viable_translation(inverse_translation=true)

    alpha_rel = m -> m == :m1 ? Set([:e1]) : Set([:e2])
    sigma_rel = e -> e == :e1 ? Set([:m1]) : Set([:m2])
    pi_rel = m -> m == :m1 ? Set([:c1]) : Set([:c2])
    rho_rel = c -> c == :c1 ? Set([:m1]) : Set([:m2])
    dc = ERIEState{Symbol,Symbol,Symbol,Symbol}(
        alpha_rel, sigma_rel, pi_rel, rho_rel,
        _ -> Set([:c1]), _ -> Set([:e1]), Set([:c1]), :s,
    )
    target = (:s, (:s, :s))
    viable_candidate = (
        step=_ -> Set([target]),
        viable=configuration -> configuration[1] == :s,
    )
    finite_args = (
        Set([:m1, :m2]), Set([:e1, :e2]), Set([:c1, :c2]), Set([:s, :other]),
    )
    @test check_dc_viable_translation(dc, finite_args..., viable_candidate)
    bad_step = merge(viable_candidate, (step=_ -> Set{Any}(),))
    @test !check_dc_viable_translation(dc, finite_args..., bad_step)
    bad_viable = merge(viable_candidate, (viable=_ -> true,))
    @test !check_dc_viable_translation(dc, finite_args..., bad_viable)
    nonboolean_viable = merge(viable_candidate, (viable=_ -> 1,))
    @test !check_dc_viable_translation(dc, finite_args..., nonboolean_viable)

    @test check_proliferation_morphism()
    @test !check_proliferation_morphism(branch_transport=false)
    @test !check_proliferation_morphism(child_rank_le_wstar=false)
    @test !check_proliferation_morphism(phi_rich_lax=false)
    @test !check_proliferation_morphism(inverse_translation=true)

    parent_alpha = m -> m == :pm0 ? Set([:pe0, :pe1]) : Set([:pe0])
    parent_sigma = e -> e == :pe0 ? Set([:pm0, :pm1]) : Set([:pm0])
    parent_pi = _ -> Set([:pc0])
    parent_rho = _ -> Set([:pm0, :pm1])
    parent = ERIEState{Symbol,Symbol,Symbol,Symbol}(
        parent_alpha,
        parent_sigma,
        parent_pi,
        parent_rho,
        _ -> Set([:pc0]),
        _ -> Set([:pe0, :pe1]),
        Set([:pc0]),
        :ps,
    )
    child_alpha = _ -> Set([:ce0, :ce1])
    child_sigma = _ -> Set([:cm0])
    child_pi = _ -> Set([:cc0])
    child_rho = _ -> Set([:cm0])
    child = ERIEState{Symbol,Symbol,Symbol,Symbol}(
        child_alpha,
        child_sigma,
        child_pi,
        child_rho,
        _ -> Set([:cc0]),
        _ -> Set([:ce0, :ce1]),
        Set([:cc0]),
        :cs,
    )
    parent_carriers = (
        motors=[:pm0, :pm1],
        environments=[:pe0, :pe1],
        cores=[:pc0],
        states=[:ps, :ps_aux],
    )
    child_carriers = (
        motors=[:cm0],
        environments=[:ce0, :ce1],
        cores=[:cc0],
        states=[:cs, :cs_aux],
    )
    heritage_carrier = [:root, :descendant]
    rank_carrier = [:low, :high]
    candidate = (
        parent_config=(:ps, (:ps, :ps_aux)),
        child_config=(:cs, (:cs_aux, :cs)),
        record=(:literal_record, 1),
        parent_heritage=_ -> :root,
        child_heritage=_ -> :descendant,
        heritage_related=(left, right) -> left == right ||
            (left == :root && right == :descendant),
        rank_le=(left, right) -> left == :low || right == :high,
        parent_rank=:low,
        child_rank=:low,
        wstar=:high,
    )
    @test check_proliferation_morphism(
        parent,
        child,
        parent_carriers,
        child_carriers,
        heritage_carrier,
        rank_carrier,
        candidate,
    )

    # Four independently falsified proof fields.
    bad_parent_viable = merge(candidate, (
        parent_config=(:ps_aux, (:ps, :ps_aux)),
    ))
    @test !check_proliferation_morphism(
        parent, child, parent_carriers, child_carriers,
        heritage_carrier, rank_carrier, bad_parent_viable,
    )
    bad_child_viable = merge(candidate, (
        child_config=(:cs_aux, (:cs_aux, :cs)),
    ))
    @test !check_proliferation_morphism(
        parent, child, parent_carriers, child_carriers,
        heritage_carrier, rank_carrier, bad_child_viable,
    )
    bad_heritage = merge(candidate, (
        heritage_related=(left, right) -> left == right,
    ))
    @test !check_proliferation_morphism(
        parent, child, parent_carriers, child_carriers,
        heritage_carrier, rank_carrier, bad_heritage,
    )
    bad_rank_bound = merge(candidate, (child_rank=:high, wstar=:low))
    @test !check_proliferation_morphism(
        parent, child, parent_carriers, child_carriers,
        heritage_carrier, rank_carrier, bad_rank_bound,
    )

    # phi_rich is Int-valued 0/1, matching Lean Nat-valued 0/1. The two
    # following proof fields are logically equivalent under the current Lean
    # definition, but their separate executable paths are both asserted.
    child_without_branch = ERIEState{Symbol,Symbol,Symbol,Symbol}(
        _ -> Set([:ce0]),
        e -> e == :ce0 ? Set([:cm0]) : Set{Symbol}(),
        child_pi,
        child_rho,
        _ -> Set([:cc0]),
        _ -> Set([:ce0]),
        Set([:cc0]),
        :cs,
    )
    shared_counterexample = ERIEC._proliferation_richness_obligations(
        parent,
        child_without_branch,
        parent_carriers.motors,
        child_carriers.motors,
    )
    @test shared_counterexample.parent_phi == 1
    @test shared_counterexample.child_phi == 0
    @test !shared_counterexample.phi_rich_lax
    @test !shared_counterexample.branch_transport
    @test !check_proliferation_morphism(
        parent, child_without_branch, parent_carriers, child_carriers,
        heritage_carrier, rank_carrier, candidate,
    )

    # A distinct mutation fixes the same equivalence in the vacuous direction.
    parent_without_branch = ERIEState{Symbol,Symbol,Symbol,Symbol}(
        _ -> Set([:pe0]),
        e -> e == :pe0 ? Set([:pm0, :pm1]) : Set{Symbol}(),
        parent_pi,
        parent_rho,
        _ -> Set([:pc0]),
        _ -> Set([:pe0]),
        Set([:pc0]),
        :ps,
    )
    equivalent_vacuous = ERIEC._proliferation_richness_obligations(
        parent_without_branch,
        child_without_branch,
        parent_carriers.motors,
        child_carriers.motors,
    )
    @test equivalent_vacuous.parent_phi == 0
    @test equivalent_vacuous.child_phi == 0
    @test equivalent_vacuous.phi_rich_lax
    @test equivalent_vacuous.branch_transport

    # Closed encoding guards.
    unknown_candidate = merge(candidate, (unknown_field=:reject,))
    @test !check_proliferation_morphism(
        parent, child, parent_carriers, child_carriers,
        heritage_carrier, rank_carrier, unknown_candidate,
    )
    missing_candidate = Base.structdiff(candidate, (record=nothing,))
    @test !check_proliferation_morphism(
        parent, child, parent_carriers, child_carriers,
        heritage_carrier, rank_carrier, missing_candidate,
    )
    duplicate_parent_carrier = merge(parent_carriers, (states=[:ps, :ps],))
    @test !check_proliferation_morphism(
        parent, child, duplicate_parent_carrier, child_carriers,
        heritage_carrier, rank_carrier, candidate,
    )
    incomplete_parent_carrier = merge(parent_carriers, (motors=[:pm0],))
    @test !check_proliferation_morphism(
        parent, child, incomplete_parent_carrier, child_carriers,
        heritage_carrier, rank_carrier, candidate,
    )

    @test check_lineage_stays_open()
    @test !check_lineage_stays_open(phi_rich_fixed=false)
    @test !check_lineage_stays_open(asserts_eventual_periodicity=true)

    @test check_richness_inherits_generational()
    @test !check_richness_inherits_generational(child_pump=false)
    @test !check_richness_inherits_generational(phi_rich_lax=false)
    richness_witness = check_richness_inherits_generational(2, 3)
    @test richness_witness.inequality_holds
    @test richness_witness.field_valid
    @test richness_witness.contract_holds
    @test !check_richness_inherits_generational(3, 2).contract_holds
    @test !check_richness_inherits_generational(2, 3; phi_rich_lax=false).contract_holds

    @test check_rich_lineage_cofinal(5, 4)
    @test !check_rich_lineage_cofinal(5, 6)
    @test !check_rich_lineage_cofinal(5, 4; semantic_invariant=false)
    @test !check_rich_lineage_cofinal(5, 4; step_certificates=[true, true])
    @test !check_rich_lineage_cofinal(5, 4; scores=[1, 2, 3, 4, 5, 5])
    @test_throws ArgumentError check_rich_lineage_cofinal(-1, 0)
    @test_throws ArgumentError check_rich_lineage_cofinal(1, -1)

    @test check_branched_rich_lineage_cofinal(5, 4)
    @test !check_branched_rich_lineage_cofinal(5, 4;
        branch_witnesses=[true, true, false, true, true, true])
    @test !check_branched_rich_lineage_cofinal(5, 4;
        branch_transports=[true, true, false, true, true])
    @test !check_branched_rich_lineage_cofinal(5, 6)
    @test_throws ArgumentError check_branched_rich_lineage_cofinal(-1, 0)
end
