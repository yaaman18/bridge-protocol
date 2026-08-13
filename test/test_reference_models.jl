@testset "reference models" begin
    @test check_reference_models()
    @test check_arbitrarily_large_nondegenerate_models()
    @test !check_arbitrarily_large_nondegenerate_models((1, 2))
    @test check_arbitrarily_large_ax_core_discrete_models()
    @test !check_arbitrarily_large_ax_core_discrete_models((0, 2))
    @test check_arbitrarily_large_three_layer_reference_models()
    @test !check_arbitrarily_large_three_layer_reference_models((1, 2))
    @test ERIEC._STABLE_REFERENCE_CONFIG[:s0].rank == :bottom
    @test ERIEC._STABLE_REFERENCE_CONFIG[:s2].rank == :top
    @test isempty(ERIEC._STABLE_REFERENCE_CONFIG[:s2].kappa)
    @test length(Set([false, true])) == 2

    candidate = (
        states=[:s0, :s1, :s2],
        next=Dict(:s0 => :s1, :s1 => :s2, :s2 => :s2),
        config=Dict(
            :s0 => (kappa=Set([:c]), epsilon=Set([:e]), rank=:bottom),
            :s1 => (kappa=Set([:c]), epsilon=Set([:e]), rank=:top),
            :s2 => (kappa=Set{Symbol}(), epsilon=Set{Symbol}(), rank=:top),
        ),
        world_loop=ones(1, 1),
        normalized_value=1 // 1,
        top_phi=Set{Nothing}(),
        top_theta=Set{Nothing}(),
        drift=(w, kappa) -> (!w && !isempty(kappa)) || w,
        external=(_source, _target) -> false,
        core=state -> state == :s2 ? Set{Symbol}() : Set([:c]),
        multi_alpha=_ -> Set([false, true]),
        collapse_initial=(
            kappa=Set([nothing]), epsilon=Set([false, true]), rank=false,
        ),
        collapse_update=_ -> (
            kappa=Set{Nothing}(), epsilon=Set{Bool}(), rank=true,
        ),
        observe=_ -> nothing,
        region=Set([false]),
        markers=(fm1=true, fm2=false, fm3=true, fm4=true),
        reaches=(source, target) -> source == target,
    )
    checked = check_reference_models(candidate)
    @test checked.v5_1_contract_holds
    @test checked.stable_contract_holds
    @test checked.dynamic_contract_holds
    @test checked.nondegenerate_contract_holds
    @test checked.contract_holds

    bad_next = merge(candidate, (
        next=Dict(:s0 => :s0, :s1 => :s2, :s2 => :s2),
    ))
    @test !check_reference_models(bad_next).v5_1_contract_holds

    bad_world = merge(candidate, (world_loop=zeros(1, 1),))
    @test !check_reference_models(bad_world).stable_contract_holds

    bad_drift = merge(candidate, (drift=(w, _kappa) -> w,))
    bad_dynamic = check_reference_models(bad_drift)
    @test bad_dynamic.stable_contract_holds
    @test !bad_dynamic.dynamic_contract_holds

    bad_e5_candidate = merge(candidate, (
        external=(source, target) -> source == :s0 && target == :s1,
    ))
    bad_e5 = check_reference_models(bad_e5_candidate)
    @test !bad_e5.external_encoding
    @test !bad_e5.e5
    @test !bad_e5.dynamic_contract_holds

    bad_alpha = merge(candidate, (multi_alpha=_ -> Set([false]),))
    bad_nondegenerate = check_reference_models(bad_alpha)
    @test bad_nondegenerate.dynamic_contract_holds
    @test !bad_nondegenerate.nondegenerate_contract_holds
end
