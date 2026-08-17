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

function large_dc_literal(k=3)
    carrier = collect(0:(k - 1))
    states = [:unit]
    (
        schema_version=1,
        contract_id="reference_models.arbitrarily_large_dc",
        lean_decl="ERIEC.RefModel.arbitrarily_large_nondegenerate_dc",
        k=k,
        motors=copy(carrier), environments=copy(carrier), cores=copy(carrier),
        states=states,
        alpha=Dict(m => copy(carrier) for m in carrier),
        sigma=Dict(e => copy(carrier) for e in carrier),
        pi=Dict(m => copy(carrier) for m in carrier),
        rho=Dict(c => copy(carrier) for c in carrier),
        kappa=Dict(:unit => copy(carrier)),
        epsilon=Dict(:unit => copy(carrier)),
        boundary=copy(carrier), state=:unit,
    )
end

function large_ax_literal(k=3)
    carrier = collect(0:(k - 1))
    states = [:s0, :s1, :s2]
    full = Dict(:s0 => copy(carrier), :s1 => copy(carrier), :s2 => Int[])
    next = Dict(:s0 => :s1, :s1 => :s2, :s2 => :s2)
    stable = (
        id=:large_stable_v1,
        motors=copy(carrier), environments=copy(carrier), cores=copy(carrier),
        states=states,
        relation_tag=:fin_full_relation_v1,
        dc_constructor=:large_ax_core_dc_v1,
        frame_constructor=:large_dyn_frame_v1,
        total_next=copy(next),
        kappa=copy(full), epsilon=copy(full),
        omega=Dict(:s0 => false, :s1 => true, :s2 => true),
        next=next, boundary=copy(carrier), state=:s0,
        phi_tag=:large_ref_phi_v1,
        theta_tag=:large_ref_theta_v1,
        drift_tag=:large_ref_drift_v1,
        step_tag=:ref_step_v1,
    )
    dynamic = (
        stable_id=:large_stable_v1,
        r2_tag=:large_ref_drift_r2prime_v1,
        external_tag=:large_ref_external_v1,
        core_tag=:large_ref_core_v1,
        core_iso_tag=:equality_v1,
        e5_tag=:large_ref_e5_v1,
    )
    (
        schema_version=1,
        contract_id="reference_models.arbitrarily_large_ax_core_discrete",
        lean_decl="ERIEC.RefModel.arbitrarily_large_ax_core_discrete_model",
        k=k, stable=stable, dynamic=dynamic, same_stable_id=:large_stable_v1,
    )
end

function three_layer_literal(k=3)
    initial = (kappa=Set([nothing]), epsilon=Set([false, true]), rank=false)
    collapsed = (kappa=Set{Nothing}(), epsilon=Set{Bool}(), rank=true)
    (
        schema_version=1,
        contract_id="reference_models.arbitrarily_large_three_layer",
        lean_decl="ERIEC.RefModel.arbitrarily_large_three_layer_reference_model",
        k=k,
        tier1=large_ax_literal(k),
        bridge=(
            dc_stable_id=:large_stable_v1,
            world_tag=:stable_world_identity_v1,
            direction=[1 // 1],
            normalized_value=1 // 1,
        ),
        section13_2=(
            bool_states=[false, true],
            multi_alpha=Dict(:unit => [false, true]),
            collapse_initial=initial,
            collapse_after_initial=collapsed,
            collapse_after_collapsed=collapsed,
            observe=Dict(false => :unit, true => :unit),
            region=[false],
            markers=(fm1=true, fm2=false, fm3=true, fm4=true),
            reaches=Dict(
                (false, false) => true, (false, true) => false,
                (true, false) => false, (true, true) => true,
            ),
        ),
    )
end

@testset "order-11 closed large-reference decoders" begin
    dc = large_dc_literal()
    @test check_arbitrarily_large_nondegenerate_models(dc)
    @test !check_arbitrarily_large_nondegenerate_models(merge(dc, (schema_version=2,)))
    @test !check_arbitrarily_large_nondegenerate_models(merge(dc, (lean_decl="wrong",)))
    @test !check_arbitrarily_large_nondegenerate_models(merge(dc, (motors=[0, 1, 1],)))
    @test !check_arbitrarily_large_nondegenerate_models(merge(dc, (
        alpha=Dict(0 => [0], 1 => [0], 2 => [0]),
    )))
    @test !check_arbitrarily_large_nondegenerate_models(merge(dc, (
        alpha=Dict(0 => [0, 1, 2], 1 => [0, 1, 2]),
    )))
    @test !check_arbitrarily_large_nondegenerate_models(merge(dc, (boundary=Int[],)))
    @test !check_arbitrarily_large_nondegenerate_models(merge(dc, (unexpected=true,)))

    ax = large_ax_literal()
    checked_ax = check_arbitrarily_large_ax_core_discrete_models(ax)
    @test checked_ax.contract_holds
    @test all((checked_ax.dc, checked_ax.frame, checked_ax.total, checked_ax.cards,
        checked_ax.multivalued, checked_ax.hinge_nonempty, checked_ax.internal_total,
        checked_ax.r2, checked_ax.e5, checked_ax.same_stable))
    @test !check_arbitrarily_large_ax_core_discrete_models(merge(ax, (
        stable=merge(ax.stable, (relation_tag=:unknown,)),
    ))).contract_holds
    @test !check_arbitrarily_large_ax_core_discrete_models(merge(ax, (
        stable=merge(ax.stable, (next=Dict(:s0 => :s0, :s1 => :s2, :s2 => :s2),)),
    ))).contract_holds
    @test !check_arbitrarily_large_ax_core_discrete_models(merge(ax, (
        dynamic=merge(ax.dynamic, (stable_id=:other,)),
    ))).contract_holds
    @test !check_arbitrarily_large_ax_core_discrete_models(merge(ax, (
        same_stable_id=:other,
    ))).contract_holds
    @test !check_arbitrarily_large_ax_core_discrete_models(merge(ax, (
        stable=merge(ax.stable, (motors=[0, 1, 1],)),
    ))).contract_holds

    three = three_layer_literal()
    checked_three = check_arbitrarily_large_three_layer_reference_models(three)
    @test checked_three.contract_holds
    @test all((checked_three.tier1_contract_holds, checked_three.bridge_identity,
        checked_three.direction_nonzero, checked_three.direction_fixed,
        checked_three.world_nontrivial, checked_three.value_one,
        checked_three.multivalued, checked_three.collapse, checked_three.ins,
        checked_three.blind, checked_three.no_terminal))
    @test !check_arbitrarily_large_three_layer_reference_models(merge(three, (
        tier1=merge(three.tier1, (same_stable_id=:other,)),
    ))).tier1_contract_holds
    @test !check_arbitrarily_large_three_layer_reference_models(merge(three, (
        bridge=merge(three.bridge, (direction=[0 // 1],)),
    ))).contract_holds
    @test !check_arbitrarily_large_three_layer_reference_models(merge(three, (
        bridge=merge(three.bridge, (dc_stable_id=:other,)),
    ))).contract_holds
    @test !check_arbitrarily_large_three_layer_reference_models(merge(three, (
        section13_2=merge(three.section13_2, (
            multi_alpha=Dict(:unit => [false]),
        )),
    ))).section13_2_contract_holds
    @test !check_arbitrarily_large_three_layer_reference_models(merge(three, (
        section13_2=merge(three.section13_2, (
            markers=(fm1=true, fm2=true, fm3=true, fm4=true),
        )),
    ))).section13_2_contract_holds
    @test !check_arbitrarily_large_three_layer_reference_models(merge(three, (
        section13_2=merge(three.section13_2, (unknown=true,)),
    ))).contract_holds
end
