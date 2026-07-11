@testset "finite dynamics" begin
    update(state) = (core=max(state.core - 1, 0),)
    intrinsic(state) = 1:state.core

    @test check_finite_collapse(update, intrinsic, (core=3,); max_steps=3)
    @test !check_finite_collapse(identity, intrinsic, (core=1,); max_steps=3)
    @test_throws ArgumentError check_finite_collapse(
        update,
        intrinsic,
        (core=1,);
        max_steps=-1,
    )

    configuration = (kappa=Set([:a, :b]), epsilon=Set([:x, :y]), rank=0)
    updated = finite_update(
        (_rank, core) -> intersect(Set(core), Set([:b])),
        (_rank, sensory) -> intersect(Set(sensory), Set([:y])),
        (rank, _core) -> rank + 1,
        configuration,
    )
    @test updated == (kappa=Set([:b]), epsilon=Set([:y]), rank=1)

    total = FiniteTotalNext(
        [:s0, :s1, :s2],
        state -> state == :s0 ? :s1 : :s2,
        (source, target) ->
            (source, target) in Set([(:s0, :s1), (:s1, :s2), (:s2, :s2)]),
    )
    @test check_total_next(total)
    @test total_orbit_prefix(total, :s0, 4) == [:s0, :s1, :s2, :s2, :s2]
    @test_throws ArgumentError total_orbit_prefix(total, :s0, -1)
    invalid_total = FiniteTotalNext([:s0], _ -> :outside, (_source, _target) -> true)
    @test !check_total_next(invalid_total)
    @test_throws ArgumentError total_orbit_prefix(invalid_total, :s0, 1)

    states = [:a, :b, :v, :dead]
    step(source, target) = (source, target) in Set([
        (:a, :b),
        (:b, :v),
        (:v, :v),
        (:dead, :dead),
    ])
    viable = Set([:v])
    @test finite_reachable(states, step, :a, :v)
    @test !finite_reachable(states, step, :dead, :v)
    @test down_to_viable(states, viable, step) == Set([:a, :b, :v])
    @test check_k_absorbing(states, viable, step)
    @test check_boundary_oneway(states, viable, step)
    boundary_step(source, target) = step(source, target) || (source, target) == (:b, :dead)
    @test finite_boundary_pairs(states, viable, boundary_step) == [
        (source=:b, target=:dead),
    ]

    bad_step(source, target) = step(source, target) || (source, target) == (:dead, :v)
    @test down_to_viable(states, viable, bad_step) == Set(states)
    @test isempty(finite_boundary_pairs(states, viable, bad_step))
    @test check_k_absorbing(states, viable, bad_step)
    @test check_boundary_oneway(states, viable, bad_step)

    mixed_observation(state) = state in (:dead, :a) ? :same : state
    injective_observation(state) = state
    @test check_ins_mixed_fiber(states, Set([:dead]), mixed_observation)
    @test !check_ins_mixed_fiber(states, Set([:dead]), injective_observation)
end
