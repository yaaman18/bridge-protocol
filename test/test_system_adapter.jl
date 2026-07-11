@testset "system adapter" begin
    adapter = SigmaSystemAdapter(
        [1.0, 2.0],
        (state, action) -> [
            state[1] + action[1],
            state[2] * action[2],
        ],
        state -> [
            state[1] + state[2],
            state[1] - state[2],
        ],
    )
    action = [0.0, 1.0]

    @test system_state(adapter, action) == [1.0, 2.0]
    advanced = advance_system_adapter(adapter, action)
    @test advanced.state == [1.0, 2.0]
    @test system_state(advanced, [1.0, 3.0]) == [2.0, 6.0]
    @test system_features(adapter, action) == [3.0, -1.0]
    @test system_sigma(adapter)(action) == [3.0, -1.0]
    @test check_sigma_dimensions(adapter, action; n_M=2, n_E=2)
    @test !check_sigma_dimensions(adapter, action; n_M=3, n_E=2)
    @test !check_sigma_dimensions(adapter, action; n_M=2, n_E=3)

    tensor = system_sensitivity_tensor(adapter, action)
    @test tensor ≈ [
        1.0 2.0
        1.0 -2.0
    ]

    identity_adapter = SigmaSystemAdapter(
        nothing,
        (_, action) -> action,
        state -> state,
    )
    world = system_actuated_world(identity_adapter, [0.0, 0.0]; target=1.0, tol=1e-10)
    @test world_nontrivial(world)

    svd_world = system_actuated_world(
        identity_adapter,
        [0.0, 0.0];
        target=1.0,
        tol=1e-10,
        method=:svd,
        seed=7,
    )
    @test svd_world.loop isa TensorGramOperator
    pipeline = run_system_pipeline(
        identity_adapter,
        [0.0, 0.0],
        DCResult(true, true, true, true, Set([:act]));
        wld_method=:svd,
        wld_seed=7,
        fixed_tol=1e-10,
    )
    @test pipeline.wld_result.loop isa TensorGramOperator
    @test world.loop ≈ [
        1.0 0.0
        0.0 1.0
    ]
end
