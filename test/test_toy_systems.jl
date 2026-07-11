@testset "toy recurrent system" begin
    system = ToyRecurrentSystem(
        zeros(2, 2),
        [
            1.0 0.0
            0.0 1.0
        ],
    )
    initial_state = [0.0, 0.0]
    action = [0.0, 0.0]
    adapter = toy_recurrent_adapter(system, initial_state)

    next_state = system_state(adapter, action)
    @test next_state ≈ [0.0, 0.0]

    features = system_features(adapter, action)
    @test features ≈ [
        0.0,
        0.0,
        0.0,
        0.0,
    ]

    tensor = system_sensitivity_tensor(adapter, action)
    @test tensor ≈ [
        0.5 0.5
        0.0 0.0
        1.0 0.0
        0.0 1.0
    ]

    world = system_actuated_world(adapter, action; target=1.0, tol=1e-10)
    @test world_nontrivial(world)
    @test world.loop ≈ [
        1.25 0.25
        0.25 1.25
    ]

    weights = ones(size(tensor, 2))
    @test weighted_sensitivity(tensor, weights) ≈ tensor

    dc = DCResult(true, true, true, true, Set([:toy_act]))
    direction = [1.0, -1.0] / sqrt(2)
    bridge = DCWorldBridge(dc, world, direction; fixed_tol=1e-10)
    @test check_worlddc_bridge(bridge)
    @test check_worlddc_bridge(dc_world_bridge(dc, world; fixed_tol=1e-10))

    summary = summarize_observation(features, world, dc)
    @test summary.world_summary.nontrivial
    @test summary.dc_summary.is_dc
    @test summary.sensory_summary.length == 4

    pipeline = run_system_pipeline(
        adapter,
        action,
        dc;
        weights=weights,
        direction=direction,
        eig_tol=1e-10,
        fixed_tol=1e-10,
        reachable_directions=direction,
        action_index=1,
        fm1_with_action=true,
        fm1_without_action=false,
        interoceptive_signal=[0.1],
    )
    @test pipeline.sensory == features
    @test pipeline.tensor ≈ tensor
    @test pipeline.weighted_tensor ≈ tensor
    @test check_worlddc_bridge(pipeline.bridge)
    @test pipeline.summary.world_summary.nontrivial
    @test pipeline.reachability.reachable
    @test pipeline.slowing_score > 0
    @test pipeline.markers isa FMMarkers
    @test pipeline.classification == :conscious
    @test summarize_pipeline_result(pipeline).classification == :conscious

    altered = toy_recurrent_adapter(
        ToyRecurrentSystem(zeros(2, 2), [
            1.0 0.0
            0.0 0.5
        ]),
        initial_state,
    )
    comparison = compare_umwelt(adapter, altered, action; eig_tol=1e-10)
    @test comparison.changed

    series = run_system_series(
        adapter,
        [action, action],
        dc;
        weights=weights,
        direction=direction,
        eig_tol=1e-10,
        fixed_tol=1e-10,
        action_index=1,
        fm1_with_action=true,
        fm1_without_action=false,
        interoceptive_signal=[0.1],
    )
    @test length(series.results) == 2
    @test series.classifications == [:conscious, :conscious]

    @test_throws DimensionMismatch ToyRecurrentSystem(zeros(2, 3), zeros(2, 2))
    @test_throws DimensionMismatch ToyRecurrentSystem(zeros(2, 2), zeros(3, 2))
    @test_throws DimensionMismatch toy_recurrent_step(system, [0.0], action)
    @test_throws DimensionMismatch toy_recurrent_step(system, initial_state, [0.0])
end
