using LinearAlgebra

@testset "field coupled system adapter" begin
    kernel = [
        0.0 0.25 0.0
        0.25 0.0 0.25
        0.0 0.25 0.0
    ]
    basis = [
        [
            1.0 0.0 0.0
            0.0 0.0 0.0
            0.0 0.0 0.0
        ],
        [
            0.0 0.0 0.0
            0.0 1.0 0.0
            0.0 0.0 0.0
        ],
    ]
    system = field_coupled_system(kernel, basis; step_gain=0.5)
    initial = zeros(3, 3)
    action = [0.1, 0.2]

    intervention = field_intervention(system, action)
    @test intervention[1, 1] ≈ 0.1
    @test intervention[2, 2] ≈ 0.2

    stepped = field_step(system, initial, action)
    @test size(stepped) == (3, 3)
    @test field_features(stepped) isa Vector
    @test length(field_features(stepped)) == 6

    adapter = field_system_adapter(system, initial)
    @test check_sigma_dimensions(adapter, action; n_M=2, n_E=6)
    tensor = system_sensitivity_tensor(adapter, zeros(2))
    @test size(tensor) == (6, 2)
    @test rank(tensor) > 0

    world = system_actuated_world(adapter, zeros(2); target=1.0, tol=1.0)
    @test size(world.loop) == (2, 2)

    @test_throws DimensionMismatch field_intervention(system, [1.0])
    @test_throws DimensionMismatch field_coupled_system(zeros(2, 3), basis)
    @test_throws DimensionMismatch field_system_adapter(system, zeros(2, 2))

    lenia = lenia_field_system(kernel, basis; config=LeniaAdapterConfig(mu=0.15, sigma=0.05))
    @test lenia_growth(0.15; mu=0.15, sigma=0.05) ≈ 1.0
    lenia_next = lenia_step(lenia, initial, action)
    @test size(lenia_next) == (3, 3)

    lenia_adapter = lenia_system_adapter(lenia, initial)
    @test check_sigma_dimensions(lenia_adapter, action; n_M=2, n_E=6)
    lenia_tensor = system_sensitivity_tensor(lenia_adapter, zeros(2))
    @test size(lenia_tensor) == (6, 2)
    @test rank(lenia_tensor) > 0

    normalized_lenia = normalized_system_adapter(lenia_adapter, zeros(2))
    normalized_world = system_actuated_world(normalized_lenia, zeros(2); target=1.0, tol=1e-6)
    @test world_nontrivial(normalized_world)

    dc = DCResult(true, true, true, true, Set([:lenia_act]))
    report = observation_structure_report(
        normalized_lenia,
        zeros(2),
        dc;
        eig_tol=1e-6,
        fixed_tol=1e-5,
        action_index=1,
        interoceptive_signal=[0.1],
    )
    @test report.pipeline.summary.world_summary.nontrivial
    @test occursin("\"Wld_projection\":", observation_artifact_json(report))

    default_system = default_lenia_system(
        (5, 5);
        action_count=16,
        feature_count=32,
        kernel_size=3,
    )
    @test length(default_system.action_basis) == 16
    action_contract = lenia_body_action_contract(default_system)
    @test action_contract.valid
    @test action_contract.action_semantics == :field_intervention
    @test action_contract.kernel_parameter_role == :experiment_condition
    @test action_contract.production_dimension
    @test action_contract.profile == :production
    @test check_lenia_body_action_contract(default_system)
    @test length(lenia_action_basis((5, 5); action_count=16)) == 16
    @test size(lenia_gaussian_kernel(3)) == (3, 3)
    @test sum(lenia_gaussian_kernel(3)) ≈ 1.0

    default_adapter = lenia_system_adapter(default_system, zeros(5, 5))
    @test check_sigma_dimensions(default_adapter, zeros(16); n_M=16, n_E=32)
    @test length(lenia_features(zeros(5, 5); n=32)) == 32
    @test length(lenia_features(zeros(5, 5); n=64)) == 64

    prototype_contract = lenia_body_action_contract(lenia)
    @test prototype_contract.valid
    @test !prototype_contract.production_dimension
    @test prototype_contract.profile == :prototype

    alternate_conditions = LeniaExperimentConditions(mu=0.25, sigma=0.08)
    alternate_lenia = lenia_field_system(kernel, basis; config=alternate_conditions)
    @test field_intervention(lenia, action) == field_intervention(alternate_lenia, action)
    @test lenia.config.mu != alternate_lenia.config.mu

    @test_throws ArgumentError LeniaExperimentConditions(sigma=0.0)
    @test_throws ArgumentError LeniaExperimentConditions(dt=0.0)
    @test_throws ArgumentError LeniaExperimentConditions(tau_steps=0)
    @test_throws ArgumentError LeniaExperimentConditions(feature_count=7)

    zero_initial = lenia_initial_field((4, 4))
    @test zero_initial == zeros(4, 4)
    noisy_config = LeniaInitialConditionConfig(
        mode=:uniform_noise,
        seed=7,
        baseline=0.5,
        amplitude=0.1,
    )
    noisy_initial = lenia_initial_field((4, 4); config=noisy_config)
    @test noisy_initial == lenia_initial_field((4, 4); config=noisy_config)
    @test noisy_initial != lenia_initial_field(
        (4, 4);
        config=LeniaInitialConditionConfig(
            mode=:uniform_noise,
            seed=8,
            baseline=0.5,
            amplitude=0.1,
        ),
    )
    @test all(value -> 0 <= value <= 1, noisy_initial)
    blob = lenia_initial_field(
        (5, 5);
        config=LeniaInitialConditionConfig(mode=:gaussian_blob, amplitude=1.0),
    )
    @test blob[3, 3] == maximum(blob)
    @test_throws ArgumentError LeniaInitialConditionConfig(mode=:unknown)
    @test_throws ArgumentError LeniaInitialConditionConfig(amplitude=-0.1)

    arch = run_lenia_architecture(
        shape=(3, 3),
        action_count=2,
        feature_count=6,
        kernel_size=3,
    )
    @test arch.report.pipeline.summary.world_summary.nontrivial
    @test arch.harness.accepted
    @test arch.reachability.reachability.reachable
    @test arch.status.harness_accepted
    @test arch.status.reachable
    @test arch.status.code == architecture_warn
    @test arch.status.slowing_warning
    @test arch.status.action_profile == :prototype
    @test arch.status.action_semantics == :field_intervention
    @test arch.status.kernel_parameter_role == :experiment_condition
    @test !arch.status.production_action_dimension
    @test arch.status.initial_condition_mode == :zeros
    @test arch.status.initial_condition_seed === nothing
    @test summarize_lenia_architecture(arch).status.harness_accepted
    @test arch.artifact isa ObservationArtifact
    @test arch.artifact.phenomenal_claim == :not_certified
    @test length(arch.artifact.system_fingerprint) == 64
    @test parse_observation_artifact_json(arch.artifact_json).system_fingerprint ==
          arch.artifact.system_fingerprint
    @test occursin("\"schema_version\":1", arch.artifact_json)
    @test occursin("\"phenomenal_claim\":\"not_certified\"", arch.artifact_json)

    modified_arch = run_lenia_architecture(
        shape=(3, 3),
        action_count=2,
        feature_count=6,
        kernel_size=3,
        action=[0.2, 0.0],
    )
    artifact_diff = umwelt_relative_diff(arch.artifact, modified_arch.artifact)
    @test artifact_diff.relative
    @test artifact_diff.projection_norm_diff > 1e-6
    certification = verify_lean_certified_artifact()
    certified_arch = run_lenia_architecture(
        shape=(3, 3),
        action_count=2,
        feature_count=6,
        kernel_size=3;
        certificate_check=certification,
    )
    @test occursin("\"payload\":", certified_arch.artifact_json)
    @test occursin("\"certificate\":", certified_arch.artifact_json)
    @test occursin("\"execution_layer\":\"julia_unverified\"", certified_arch.artifact_json)
    @test occursin("\"execution_certified\":false", certified_arch.artifact_json)
    @test parse_observation_artifact_json(
        certified_arch.artifact_json,
    ).phenomenal_claim == :not_certified
    status_certificate = lenia_architecture_status_certificate(certified_arch)
    @test status_certificate.ok
    @test status_certificate.kind == :LeniaArchitectureStatus
    @test status_certificate.execution_layer == :julia_unverified
    @test !status_certificate.execution_certified
    @test status_certificate.execution_boundary == :unverified_runtime
    @test status_certificate.action_profile == :prototype
    @test status_certificate.action_semantics == :field_intervention
    @test status_certificate.kernel_parameter_role == :experiment_condition
    @test !status_certificate.production_action_dimension
    @test status_certificate.initial_condition_mode == :zeros
    @test status_certificate.system_fingerprint ==
          certified_arch.artifact.system_fingerprint
    @test status_certificate.phenomenal_claim == :not_certified

    noisy_arch = run_lenia_architecture(
        shape=(3, 3),
        action_count=2,
        feature_count=6,
        kernel_size=3,
        initial_condition=LeniaInitialConditionConfig(
            mode=:uniform_noise,
            seed=9,
            baseline=0.5,
            amplitude=0.01,
        ),
    )
    @test noisy_arch.status.initial_condition_mode == :uniform_noise
    @test noisy_arch.status.initial_condition_seed == 9
    @test noisy_arch.artifact.system_fingerprint != arch.artifact.system_fingerprint
    @test_throws ArgumentError run_lenia_architecture(
        shape=(3, 3),
        action_count=2,
        feature_count=6,
        kernel_size=3,
        initial_field=zeros(3, 3),
        initial_condition=LeniaInitialConditionConfig(mode=:uniform_noise),
    )
    certified_status = certified_lenia_architecture_status(certified_arch, certification)
    @test certified_status.payload.status == "architecture_warn"
    @test certified_status.certificate.ok
    status_graph = certificate_dependency_graph(certified_status)
    @test "worlddc.bridge" in status_graph.lean_contracts
    @test "architecture_status" in status_graph.julia_checkers
    @test status_graph.trust.execution_layer == :julia_unverified
    @test !status_graph.trust.execution_certified
    @test status_graph.trust.execution_boundary == :unverified_runtime
    @test occursin(
        "\"kind\":\"LeniaArchitectureStatus\"",
        certified_lenia_architecture_status_json(certified_arch, certification),
    )
    @test occursin(
        "\"execution_layer\":\"julia_unverified\"",
        certified_lenia_architecture_status_json(certified_arch, certification),
    )

    consumer = TRMConsumer(default_trm_program(); steps=1)
    rollout = run_trm_closed_rollout(
        lenia_adapter,
        zeros(2),
        dc;
        consumer=consumer,
        steps=2,
        normalize_pipeline=true,
        eig_tol=1e-6,
        fixed_tol=1e-5,
    )
    @test length(rollout.steps) == 2
    @test length(rollout.steps[1].feedback_action) == 2
    @test rollout.steps[2].input_action ≈ rollout.steps[1].feedback_action
    @test rollout.final_action ≈ rollout.steps[end].feedback_action
    @test rollout.final_adapter.state != lenia_adapter.state
    rollout_summary = summarize_trm_closed_rollout(rollout)
    @test rollout_summary.steps == 2
    @test all(rollout_summary.world_nontrivial)

    tau = compare_lenia_tau_steps(
        [1];
        shape=(3, 3),
        action_count=2,
        feature_count=6,
        kernel_size=3,
        acceptance_config=nothing,
    )
    @test length(tau.results) == 1
    @test length(tau.summary) == 1
    @test tau.summary[1].harness_accepted
    @test tau.summary[1].reachable
    @test tau.summary[1].status == architecture_warn
    @test tau.summary[1].reproducibility === nothing
    @test occursin("\"artifacts\":", tau.artifact_json)
    @test occursin("\"phenomenal_claim\":\"not_certified\"", tau.artifact_json)
    repeated_tau = compare_lenia_tau_steps(
        [1];
        shape=(3, 3),
        action_count=2,
        feature_count=6,
        kernel_size=3,
        acceptance_config=ExperimentAcceptanceConfig(),
    )
    @test length(repeated_tau.replicates[1]) == 3
    @test repeated_tau.summary[1].reproducibility.accepted
    @test repeated_tau.summary[1].reproducibility.seed == 42
    @test repeated_tau.summary[1].reproducibility.repeats == 3
    @test occursin("\"reproducibility\":", repeated_tau.artifact_json)
    repeated_tau_certificate = lenia_tau_sweep_certificate(repeated_tau)
    @test repeated_tau_certificate.ok
    @test repeated_tau_certificate.reproducibility_enabled
    @test repeated_tau_certificate.reproducibility_assessment_count == 1
    @test repeated_tau_certificate.reproducibility_accepted_count == 1
    rejected_reproducibility = merge(
        repeated_tau.summary[1].reproducibility,
        (accepted=false, max_relative_deviation=0.02),
    )
    rejected_series = merge(
        repeated_tau,
        (reproducibility=[rejected_reproducibility],),
    )
    @test !lenia_tau_sweep_certificate(rejected_series).ok
    certified_tau = compare_lenia_tau_steps(
        [1];
        shape=(3, 3),
        action_count=2,
        feature_count=6,
        kernel_size=3,
        certificate_check=certification,
        acceptance_config=nothing,
    )
    @test occursin("\"certificate\":", certified_tau.artifact_json)
    @test occursin("\"artifacts\":", certified_tau.artifact_json)
    tau_certificate = lenia_tau_sweep_certificate(certified_tau)
    @test tau_certificate.ok
    @test tau_certificate.kind == :LeniaTauSweep
    @test tau_certificate.result_count == 1
    certified_tau_sweep = certified_lenia_tau_sweep(certified_tau, certification)
    @test certified_tau_sweep.payload.kind == :LeniaTauSweep
    @test "compare_lenia_tau_steps" in
        certificate_dependency_graph(certified_tau_sweep).julia_checkers
    @test occursin(
        "\"kind\":\"LeniaTauSweep\"",
        certified_lenia_tau_sweep_json(certified_tau, certification),
    )

    feature_sweep = compare_lenia_feature_counts(
        [6];
        shape=(3, 3),
        action_count=2,
        kernel_size=3,
        certificate_check=certification,
        acceptance_config=nothing,
    )
    @test length(feature_sweep.results) == 1
    @test feature_sweep.summary[1].feature_count == 6
    @test occursin("\"certificate\":", feature_sweep.artifact_json)
    feature_certificate = lenia_feature_sweep_certificate(feature_sweep)
    @test feature_certificate.ok
    @test feature_certificate.kind == :LeniaFeatureSweep
    certified_feature_sweep = certified_lenia_feature_sweep(feature_sweep, certification)
    @test certified_feature_sweep.payload.kind == :LeniaFeatureSweep
    @test "compare_lenia_feature_counts" in
        certificate_dependency_graph(certified_feature_sweep).julia_checkers
    @test occursin(
        "\"kind\":\"LeniaFeatureSweep\"",
        certified_lenia_feature_sweep_json(feature_sweep, certification),
    )

    parameter_grid = compare_lenia_parameter_grid(
        [1],
        [6];
        shape=(3, 3),
        action_count=2,
        kernel_size=3,
        certificate_check=certification,
        acceptance_config=nothing,
    )
    @test length(parameter_grid.results) == 1
    @test parameter_grid.summary[1].tau_step == 1
    @test parameter_grid.summary[1].feature_count == 6
    @test occursin("\"certificate\":", parameter_grid.artifact_json)
    grid_certificate = lenia_parameter_grid_certificate(parameter_grid)
    @test grid_certificate.ok
    @test grid_certificate.kind == :LeniaParameterGrid
    certified_grid = certified_lenia_parameter_grid(parameter_grid, certification)
    @test certified_grid.payload.kind == :LeniaParameterGrid
    @test "compare_lenia_parameter_grid" in
        certificate_dependency_graph(certified_grid).julia_checkers
    @test occursin(
        "\"kind\":\"LeniaParameterGrid\"",
        certified_lenia_parameter_grid_json(parameter_grid, certification),
    )
end
