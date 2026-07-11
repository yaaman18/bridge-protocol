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

    escaping_step = (source, target) -> source == :a && target == :c
    escaping = check_viability_closure(states, escaping_step, state -> state == :a)
    @test !escaping.step_closed
    @test escaping.left_postfixed
    @test escaping.right_postfixed
    @test !escaping.fixed
    @test escaping.invariant_implies_fixed

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
end
