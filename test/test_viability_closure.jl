@testset "viability closure object map" begin
    states = [:a, :b, :c]
    stable_step = (source, target) ->
        (source == :a && target == :b) || (source == :b && target == :b)
    stable = check_viability_closure(states, stable_step, state -> state in (:a, :b))
    @test stable.viable_states == Set([:a, :b])
    @test stable.closure == Set([:a, :b])
    @test stable.step_closed
    @test stable.left_postfixed
    @test stable.right_postfixed
    @test stable.fixed
    @test stable.invariant_implies_fixed
    @test stable.contract_premises
    @test stable.contract_conclusion
    @test stable.contract_holds

    escaping_step = (source, target) -> source == :a && target == :c
    escaping = check_viability_closure(states, escaping_step, state -> state == :a)
    @test !escaping.step_closed
    @test escaping.left_postfixed
    @test escaping.right_postfixed
    @test !escaping.fixed
    @test escaping.invariant_implies_fixed
    @test !escaping.contract_premises
    @test !escaping.contract_conclusion
    @test !escaping.contract_holds

    empty = check_viability_closure(states, stable_step, _ -> false)
    @test empty.step_closed
    @test empty.fixed
    @test isempty(empty.closure)

    source_states = [:a, :b, :c]
    target_states = [:x, :y, :z]
    mapping = Dict(:a => :y, :b => :z, :c => :x)
    source_step = (source, target) ->
        (source == :a && target == :b) || (source == :b && target == :b)
    target_step = (source, target) ->
        (source == :y && target == :z) || (source == :z && target == :z)
    natural = check_viability_closure_naturality(
        source_states,
        target_states,
        mapping,
        source_step,
        target_step,
        state -> state in (:a, :b),
        state -> state in (:y, :z),
    )
    @test natural.bijective
    @test natural.step_preserved
    @test natural.viability_preserved
    @test natural.stage_natural
    @test natural.left_natural
    @test natural.right_natural
    @test natural.contract_premises
    @test natural.contract_conclusion
    @test natural.contract_holds

    all_source_subsets = powerset(Set(source_states))
    all_k_natural = check_viability_closure_naturality(
        source_states,
        target_states,
        mapping,
        source_step,
        target_step,
        state -> state in (:a, :b),
        state -> state in (:y, :z),
        all_source_subsets,
    )
    @test all_k_natural.subset_family_complete
    @test all_k_natural.subsets_in_carrier
    @test all_k_natural.subset_natural
    @test all_k_natural.contract_premises
    @test all_k_natural.contract_conclusion
    @test all_k_natural.contract_holds

    non_equiv_source = [:a, :b, :c]
    non_equiv_target = [:x, :y]
    non_equiv_mapping = Dict(:a => :x, :b => :x, :c => :y)
    non_equiv = check_viability_closure_naturality(
        non_equiv_source,
        non_equiv_target,
        non_equiv_mapping,
        (_source, _target) -> false,
        (_source, _target) -> false,
        _ -> false,
        _ -> false,
        powerset(Set(non_equiv_source)),
    )
    @test !non_equiv.bijective
    @test !non_equiv.injective
    @test !non_equiv.cardinality_equal
    @test !non_equiv.inverse_roundtrip
    @test !non_equiv.contract_holds

    incomplete_k_family = check_viability_closure_naturality(
        source_states,
        target_states,
        mapping,
        source_step,
        target_step,
        state -> state in (:a, :b),
        state -> state in (:y, :z),
        [Set{Symbol}()],
    )
    @test !incomplete_k_family.subset_family_complete
    @test incomplete_k_family.contract_conclusion
    @test !incomplete_k_family.contract_holds

    unnatural = check_viability_closure_naturality(
        source_states,
        target_states,
        mapping,
        source_step,
        target_step,
        state -> state in (:a, :b),
        state -> state == :y,
    )
    @test !unnatural.contract_premises
    @test !unnatural.contract_holds

    relational = check_viability_relational_frame(
        source_states, source_step, state -> state in (:a, :b),
    )
    @test relational.abstract_closure == Set([:a, :b])
    @test relational.left_closure == relational.abstract_closure
    @test relational.right_closure == relational.abstract_closure
    @test relational.left_realizes
    @test relational.right_realizes
    @test relational.left_postfixed
    @test relational.right_postfixed
    @test relational.left_fixed
    @test relational.contract_premises
    @test relational.contract_conclusion
    @test relational.contract_holds

    escaping_relational = check_viability_relational_frame(
        states, escaping_step, state -> state == :a,
    )
    @test !escaping_relational.contract_premises
    @test !escaping_relational.contract_conclusion
    @test !escaping_relational.contract_holds

    relational_functor = check_viability_relational_functor(
        source_states,
        target_states,
        mapping,
        source_step,
        target_step,
        state -> state in (:a, :b),
        state -> state in (:y, :z),
    )
    @test relational_functor.bijective
    @test relational_functor.pi_preserved
    @test relational_functor.rho_preserved
    @test relational_functor.alpha_preserved
    @test relational_functor.sigma_preserved
    @test relational_functor.kappa_preserved
    @test relational_functor.epsilon_preserved
    @test relational_functor.frame_iso
    @test relational_functor.contract_premises
    @test relational_functor.contract_conclusion
    @test relational_functor.contract_holds

    invalid_relational_functor = check_viability_relational_functor(
        source_states,
        target_states,
        mapping,
        source_step,
        target_step,
        state -> state in (:a, :b),
        state -> state == :y,
    )
    @test invalid_relational_functor.contract_premises
    @test !invalid_relational_functor.contract_conclusion
    @test !invalid_relational_functor.contract_holds
end
