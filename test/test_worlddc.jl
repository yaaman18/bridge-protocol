@testset "worlddc" begin
    dc_true = DCResult(true, true, true, true, Set([:act]))
    dc_false = DCResult(false, true, true, true, Set([:act]))

    wld_nontrivial = actuated_world([
        1.0 0.0
        0.0 0.5
    ]; target=1.0, tol=1e-10)
    wld_empty = actuated_world([
        0.5 0.0
        0.0 0.3
    ]; target=1.0, tol=1e-10)

    @test check_worlddc_bridge(dc_true, wld_nontrivial)
    @test !check_worlddc_bridge(dc_false, wld_nontrivial)
    @test !check_worlddc_bridge(dc_true, wld_empty)
    @test !check_worlddc_bridge(dc_false, wld_empty)

    direction = [1.0, 0.0]
    bridge = DCWorldBridge(dc_true, wld_nontrivial, direction; fixed_tol=1e-10)
    @test bridge.dc_result === dc_true
    @test bridge.wld_result === wld_nontrivial
    @test bridge.loop == wld_nontrivial.loop
    @test bridge.direction == direction
    @test bridge.act == Set([:act])
    @test bridge.fixed_residual ≈ 0.0
    @test check_worlddc_bridge(bridge)
    @test worlddc_bridge_claim() == :consistency_harness
    @test !worlddc_bridge_is_equivalence_claim()
    @test summarize_worlddc_bridge(bridge).claim == :consistency_harness
    certification = verify_lean_certified_artifact()
    bridge_certificate = dc_world_bridge_certificate(bridge)
    @test bridge_certificate.ok
    @test bridge_certificate.kind == :DCWorldBridge
    @test bridge_certificate.claim == :consistency_harness
    certified_bridge = certified_dc_world_bridge(bridge, certification)
    @test certified_bridge.payload.kind == :DCWorldBridge
    @test certified_bridge.certificate.ok
    @test occursin("\"kind\":\"DCWorldBridge\"", certified_dc_world_bridge_json(bridge, certification))
    bridge_graph = certificate_dependency_graph(certified_bridge)
    @test bridge_graph.lean_contracts == ["worlddc.bridge"]
    @test bridge_graph.julia_checkers == ["check_worlddc_bridge"]
    @test occursin("\"lean_contracts\":[\"worlddc.bridge\"]", certified_dependency_graph_json(certified_bridge))
    harness = dc_world_harness(dc_true, wld_nontrivial; direction=direction, fixed_tol=1e-10)
    @test harness.accepted
    @test harness.assumptions.claim == :consistency_harness
    @test :dc_result in harness.assumptions_used
    @test :nonzero_fixed_direction in harness.assumptions_used
    reachable_harness = dc_world_harness(
        dc_true,
        wld_nontrivial;
        direction=direction,
        reachability=(reachable=true,),
        require_reachable=true,
        fixed_tol=1e-10,
    )
    @test :ordered_reachability in reachable_harness.assumptions_used
    @test check_worlddc_bridge(dc_true, wld_nontrivial, direction; fixed_tol=1e-10)
    @test check_worlddc_bridge(dc_true, wld_nontrivial.loop, direction; fixed_tol=1e-10)

    loop_bridge = DCWorldBridge(dc_true, wld_nontrivial.loop, direction; fixed_tol=1e-10)
    @test loop_bridge.wld_result === nothing
    @test loop_bridge.loop == wld_nontrivial.loop
    @test WorldDCBridge(dc_true, wld_nontrivial, direction; fixed_tol=1e-10) isa DCWorldBridge
    @test abs(sum(world_fixed_direction(wld_nontrivial) .* direction)) ≈ 1.0
    @test dc_world_bridge(dc_true, wld_nontrivial; fixed_tol=1e-10) isa DCWorldBridge

    @test !check_worlddc_bridge(dc_false, wld_nontrivial, direction; fixed_tol=1e-10)
    @test !check_worlddc_bridge(dc_true, wld_nontrivial, [0.0, 0.0]; fixed_tol=1e-10)
    @test !check_worlddc_bridge(dc_true, wld_nontrivial, [0.0, 1.0]; fixed_tol=1e-10)
    @test !check_worlddc_bridge(dc_true, wld_nontrivial, [1.0, 0.0, 0.0]; fixed_tol=1e-10)
    @test !check_worlddc_bridge(dc_true, [1.0 0.0], [1.0, 0.0]; fixed_tol=1e-10)
    @test_throws ArgumentError world_fixed_direction(wld_empty)
    @test check_no_unconditional_worlddc()
    @test check_no_unconditional_worlddc(true, false)
    @test !check_no_unconditional_worlddc(true, true)
    @test check_forward_worlddc_counterexample(dc_true, wld_empty)
    @test !check_forward_worlddc_counterexample(dc_false, wld_empty)
    @test check_backward_worlddc_counterexample(dc_false, wld_nontrivial)
    @test !check_backward_worlddc_counterexample(dc_true, wld_nontrivial)
end
