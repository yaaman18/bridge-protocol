function _wager_interpretive_candidate(;
    ph=Set([:s0]),
    mat=Set([(:s0, :e0)]),
    conscious_hinge=Set([:s0]),
)
    (
        states=(:s0,),
        environments=(:e0,),
        dc=Set([:s0]),
        nontrivial=true,
        positive_value=Set([(:s0, :e0)]),
        conscious_hinge=conscious_hinge,
        ph=ph,
        mat=mat,
    )
end

function _wager_core_candidate(; inconsistent=false)
    environments = inconsistent ? (:false, :true) : (:e0,)
    (
        actions=(:a0,),
        environments=environments,
        cores=(:c0,),
        alpha=Dict(:a0 => Set(environments)),
        sigma=Dict(environment => inconsistent ? Set{Symbol}() : Set([:a0])
            for environment in environments),
        pi=Dict(:a0 => Set([:c0])),
        rho=Dict(:c0 => Set([:a0])),
    )
end

_wager_cycle_candidate(; dc=Set([:s0]), edges=((:s0, :s1), (:s1, :s0))) =
    (states=(:s0, :s1), dc=dc, edges=edges)

function _wager_independence_candidate()
    (
        positive=_wager_interpretive_candidate(),
        w1_negative=_wager_interpretive_candidate(ph=Set{Symbol}()),
        w2_negative=_wager_interpretive_candidate(mat=Set{Tuple{Symbol,Symbol}}()),
        w3_negative=_wager_interpretive_candidate(ph=Set{Symbol}()),
        core_positive=_wager_core_candidate(),
        core_negative=_wager_core_candidate(inconsistent=true),
        w6_positive=_wager_cycle_candidate(),
        w6_negative=_wager_cycle_candidate(dc=Set{Symbol}()),
    )
end

@testset "Frozen wagers" begin
    @test check_wager_independence()
    independence = _wager_independence_candidate()
    @test check_wager_independence(independence)
    @test !check_wager_independence(merge(independence, (
        w6_positive=_wager_cycle_candidate(edges=((:s0, :s1),)),
    )))
    @test !check_wager_independence(merge(independence, (
        core_negative=merge(independence.core_negative, (sigma=Dict(:false => Set{Symbol}()),)),
    )))
    @test check_w5_independence_family()
    @test check_w5_independence_family((2, 3, 17, 257))
    @test !check_w5_independence_family((1, 2))
    @test check_wager_conservative_extension()
    @test check_frozen_protocol_invariant()
    sentence = model -> model.wager
    packs = (model -> model.inhabited, model -> model.stable)
    positive = (wager=true, inhabited=true, stable=true)
    negative = (wager=false, inhabited=true, stable=true)
    @test check_frozen_protocol_invariant(sentence, positive, negative, packs)
    @test !check_frozen_protocol_invariant(
        sentence, positive, merge(negative, (wager=true,)), packs,
    )
    @test !check_frozen_protocol_invariant(
        sentence, positive, merge(negative, (stable=false,)), packs,
    )
    @test check_wager_named_models()
    kbad = _wager_core_candidate(inconsistent=true)
    kplus = _wager_core_candidate()
    m0 = _wager_cycle_candidate()
    mplus = _wager_cycle_candidate(dc=Set{Symbol}())
    mcyc = _wager_cycle_candidate()
    @test check_wager_named_models(kbad, kplus, m0, mplus, mcyc)
    @test !check_wager_named_models(kplus, kplus, m0, mplus, mcyc)
    @test !check_wager_named_models(
        kbad, kplus, _wager_cycle_candidate(edges=((:s0, :s1),)), mplus, mcyc,
    )
    @test !check_wager_named_models(
        kbad, kplus, m0,
        (states=(:s0,), dc=Set{Symbol}(), edges=((:s0, :outside),)), mcyc,
    )
    @test check_w6_cycle_soundness((:s0,), ((:s0, :s0),), Set([:s0]))
    @test !check_w6_cycle_soundness((:s0, :s1), ((:s0, :s1), (:s1, :s0)), Set([:s0]))
    @test check_frozen_wager_interpretive_model()
    @test !check_frozen_wager_interpretive_model(ph=Set{Symbol}())
    @test !check_frozen_wager_interpretive_model(mat=Set{Tuple{Symbol,Symbol}}())
    @test !check_frozen_wager_interpretive_model(conscious_hinge=Set{Symbol}())
    @test check_frozen_wager_model()
    @test !check_frozen_wager_model(k0=2)
    @test !check_frozen_wager_model(sigma=Dict(:e0 => Set{Symbol}()))
    @test check_frozen_wager_model(
        states=(:s0, :s1),
        dc=Set([:s0]),
        edges=((:s0, :s1), (:s1, :s0)),
    )
    @test !check_frozen_wager_model(
        states=(:s0, :s1),
        dc=Set([:s0]),
        edges=((:s0, :s1),),
    )
    @test !check_frozen_wager_model(
        states=(:s0, :s1, :s2),
        dc=Set([:s0]),
        edges=((:s0, :s1), (:s1, :s2), (:s2, :s1)),
    )
    @test check_frozen_wager_full_model()
    @test !check_frozen_wager_full_model(ph=Set{Symbol}())
    @test !check_frozen_wager_full_model(k0=2)
    @test check_frozen_wager_full_model(
        states=(:s0, :s1),
        dc=Set([:s0]),
        edges=((:s0, :s1), (:s1, :s0)),
    )
    @test !check_frozen_wager_full_model(
        states=(:s0, :s1),
        dc=Set([:s0]),
        edges=((:s0, :s1),),
    )
end
