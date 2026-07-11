@testset "minimal policy and topology" begin
    using LinearAlgebra

    tensor = [
        1.0 0.0
        0.0 2.0
    ]
    world = actuated_world(tensor; target=4.0, tol=1e-10)

    policy = MinimalPolicy()
    action = minimal_policy_action(policy, tensor, world)
    @test length(action) == 2
    @test norm(action) ≈ 1.0
    @test action[2] > action[1]

    unnormalized = minimal_policy_action(
        MinimalPolicy(gain=0.5, use_world=false, normalize=false),
        tensor,
    )
    @test unnormalized ≈ [0.5, 1.0]

    payload_action = consume(policy, (weighted_tensor=tensor, wld_result=world))
    @test payload_action ≈ action
    @test_throws ArgumentError consume(policy, (value=1,))

    catalog = topology_catalog()
    @test validate_topology(catalog.feedforward)
    @test validate_topology(catalog.recurrent)
    @test validate_topology(catalog.integrated)
    @test classify_topology(catalog.feedforward) == :feedforward
    @test classify_topology(catalog.recurrent) == :recurrent
    @test classify_topology(catalog.integrated) == :integrated

    adjacency = topology_adjacency(catalog.recurrent)
    @test size(adjacency) == (4, 4)
    @test count(adjacency) == length(catalog.recurrent.edges)

    invalid = TRMTopology([:World], [(:World, :Missing)])
    @test !validate_topology(invalid)
    @test classify_topology(invalid) == :invalid
    @test_throws ArgumentError topology_adjacency(invalid)

    pipeline = (
        tensor=tensor,
        weighted_tensor=tensor,
        wld_result=world,
        weights=[1.0, 1.0],
        summary=(ok=true,),
    )
    program = default_trm_program(catalog.recurrent; policy=policy)
    initial = trm_initial_state(pipeline; policy=policy)
    @test haskey(initial, :World)
    @test haskey(initial, :Action)

    state = run_trm_program(program, initial; steps=1)
    @test haskey(state, :Action)
    @test length(state[:Action]) == 2
    @test consume(TRMConsumer(program; steps=1), pipeline) ≈ state[:Action]

    adapter = SigmaSystemAdapter(
        zeros(2),
        (_state, action) -> action,
        state -> state,
    )
    dc = DCResult(true, true, true, true, Set([:trm_act]))
    presets = trm_neural_experiment_preset_catalog()
    @test presets.smoke.name == :smoke
    @test trm_neural_experiment_preset(:short).rollout_steps >=
        trm_neural_experiment_preset(:smoke).rollout_steps
    @test_throws ArgumentError trm_neural_experiment_preset(:missing)
    preset_certificate = trm_neural_experiment_preset_certificate(presets.smoke)
    @test preset_certificate.ok
    @test preset_certificate.kind == :TRMNeuralExperimentPreset
    rollout = run_trm_closed_rollout(
        adapter,
        zeros(2),
        dc;
        consumer=TRMConsumer(program; steps=1),
        steps=2,
        eig_tol=1e-10,
    )
    dataset = trm_rollout_dataset(rollout)
    @test check_trm_rollout_dataset(dataset)
    @test length(dataset.samples) == 2
    @test dataset.samples[1].target_action ≈ rollout.steps[1].feedback_action
    @test dataset.samples[1].metadata.world_nontrivial
    @test trm_action_mse(dataset.samples[1].target_action, dataset.samples[1].target_action) ≈ 0.0
    certification = verify_certified_artifact(
        parse_certified_artifact("ERIEC_CERTIFIED_ARTIFACT\t1\ttest-boundary\n"),
    )
    certified_preset = certified_trm_neural_experiment_preset(presets.smoke, certification)
    @test certified_preset.payload.kind == :TRMNeuralExperimentPreset
    @test "trm_neural_experiment_preset_certificate" in
        certificate_dependency_graph(certified_preset).julia_checkers
    @test occursin(
        "\"kind\":\"TRMNeuralExperimentPreset\"",
        certified_trm_neural_experiment_preset_json(presets.smoke, certification),
    )
    dataset_certificate = trm_rollout_dataset_certificate(dataset)
    @test dataset_certificate.ok
    @test dataset_certificate.kind == :TRMRolloutDataset
    @test dataset_certificate.sample_count == 2
    certified_dataset = certified_trm_rollout_dataset(dataset, certification)
    @test certified_dataset.payload.kind == :TRMRolloutDataset
    @test certified_dataset.certificate.ok
    @test occursin(
        "\"sample_count\":2",
        certified_trm_rollout_dataset_json(dataset, certification),
    )
    dataset_graph = certificate_dependency_graph(certified_dataset)
    @test isempty(dataset_graph.lean_contracts)
    @test dataset_graph.julia_checkers == ["check_trm_rollout_dataset"]
    feature = trm_learning_feature_vector(dataset.samples[1].observation)
    @test !isempty(feature)
    model = fit_trm_linear_action_model(dataset; ridge=1e-6)
    @test model isa TRMLinearActionModel
    @test size(model.weights, 2) == length(feature)
    @test length(trm_predict_action(model, dataset.samples[1].observation)) == 2
    @test model.training_loss >= 0.0
    model_certificate = trm_linear_action_model_certificate(model, dataset)
    @test model_certificate.ok
    @test model_certificate.feature_dim == length(feature)
    certified_model = certified_trm_linear_action_model(model, dataset, certification)
    @test certified_model.payload.kind == :TRMLinearActionModel
    @test "trm_dataset_loss" in certificate_dependency_graph(certified_model).julia_checkers
    @test occursin(
        "\"kind\":\"TRMLinearActionModel\"",
        certified_trm_linear_action_model_json(model, dataset, certification),
    )
    training_step = trm_linear_training_step(dataset; ridge=1e-6)
    @test training_step.model isa TRMLinearActionModel
    @test training_step.summary.accepted
    @test training_step.summary.model_loss <= training_step.summary.baseline_loss + 1e-10
    @test length(training_step.predictions) == length(dataset.samples)
    step_certificate = trm_training_step_certificate(training_step)
    @test step_certificate.ok
    @test step_certificate.kind == :TRMTrainingStep
    certified_step = certified_trm_training_step(training_step, certification)
    @test certified_step.payload.accepted
    step_graph = certificate_dependency_graph(certified_step)
    @test "fit_trm_linear_action_model" in step_graph.julia_checkers
    @test occursin(
        "\"kind\":\"TRMTrainingStep\"",
        certified_trm_training_step_json(training_step, certification),
    )
    neural_model = fit_trm_neural_action_model(
        dataset;
        hidden_dim=4,
        activation=:tanh,
        learning_rate=0.05,
        epochs=10,
    )
    @test neural_model isa TRMNeuralActionModel
    @test neural_model.activation == :tanh
    @test size(neural_model.input_weights, 1) == 4
    @test length(trm_predict_action(neural_model, dataset.samples[1].observation)) == 2
    @test neural_model.training_loss >= 0.0
    @test_throws ArgumentError fit_trm_neural_action_model(dataset; epochs=0)
    neural_certificate = trm_neural_action_model_certificate(neural_model, dataset)
    @test neural_certificate.ok
    @test neural_certificate.hidden_dim == 4
    @test neural_certificate.numeric_assumptions.activation == :tanh
    certified_neural = certified_trm_neural_action_model(neural_model, dataset, certification)
    @test certified_neural.payload.kind == :TRMNeuralActionModel
    @test "trm_predict_action" in certificate_dependency_graph(certified_neural).julia_checkers
    @test occursin(
        "\"kind\":\"TRMNeuralActionModel\"",
        certified_trm_neural_action_model_json(neural_model, dataset, certification),
    )
    neural_step = trm_neural_training_step(
        dataset;
        hidden_dim=4,
        activation=:tanh,
        learning_rate=0.05,
        epochs=10,
    )
    @test neural_step.model isa TRMNeuralActionModel
    @test neural_step.summary.accepted
    @test neural_step.summary.activation == :tanh
    neural_step_certificate = trm_neural_training_step_certificate(neural_step)
    @test neural_step_certificate.ok
    @test neural_step_certificate.kind == :TRMNeuralTrainingStep
    certified_neural_step = certified_trm_neural_training_step(neural_step, certification)
    @test certified_neural_step.payload.kind == :TRMNeuralTrainingStep
    @test "fit_trm_neural_action_model" in
        certificate_dependency_graph(certified_neural_step).julia_checkers
    @test occursin(
        "\"kind\":\"TRMNeuralTrainingStep\"",
        certified_trm_neural_training_step_json(neural_step, certification),
    )
    neural_run = trm_neural_training_run(
        dataset;
        hidden_dim=4,
        activation=:tanh,
        learning_rate=0.05,
        checkpoint_count=2,
        epochs_per_checkpoint=5,
    )
    @test neural_run isa TRMTrainingRunResult
    @test length(neural_run.checkpoints) == 2
    @test neural_run.final_model isa TRMNeuralActionModel
    @test neural_run.summary.accepted
    @test neural_run.summary.cumulative_epochs == 10
    @test neural_run.checkpoints[2].summary.cumulative_epochs == 10
    neural_run_certificate = trm_neural_training_run_certificate(neural_run)
    @test neural_run_certificate.ok
    @test neural_run_certificate.kind == :TRMNeuralTrainingRun
    @test neural_run_certificate.numeric_assumptions.checkpoint_count == 2
    certified_neural_run = certified_trm_neural_training_run(neural_run, certification)
    @test certified_neural_run.payload.kind == :TRMNeuralTrainingRun
    @test "trm_neural_training_run" in
        certificate_dependency_graph(certified_neural_run).julia_checkers
    @test occursin(
        "\"kind\":\"TRMNeuralTrainingRun\"",
        certified_trm_neural_training_run_json(neural_run, certification),
    )
    optimizer_state = trm_neural_optimizer_state(neural_run)
    @test optimizer_state isa TRMNeuralOptimizerState
    @test optimizer_state.summary.checkpoint_count == 2
    @test optimizer_state.summary.cumulative_epochs == 10
    @test length(optimizer_state.loss_trace) == 2
    @test length(optimizer_state.epoch_trace) == 2
    @test occursin(
        "\"kind\":\"TRMNeuralOptimizerState\"",
        trm_neural_optimizer_state_json(optimizer_state),
    )
    optimizer_certificate = trm_neural_optimizer_state_certificate(optimizer_state)
    @test optimizer_certificate.ok
    @test optimizer_certificate.monotone_epochs
    certified_optimizer = certified_trm_neural_optimizer_state(optimizer_state, certification)
    @test certified_optimizer.payload.kind == :TRMNeuralOptimizerState
    @test "trm_neural_optimizer_state_artifact" in
        certificate_dependency_graph(certified_optimizer).julia_checkers
    @test occursin(
        "\"kind\":\"TRMNeuralOptimizerState\"",
        certified_trm_neural_optimizer_state_json(optimizer_state, certification),
    )
    mktempdir() do dir
        raw_path = joinpath(dir, "optimizer.json")
        raw_tsv_path = joinpath(dir, "optimizer-state.tsv")
        certified_path = joinpath(dir, "certified-optimizer.json")
        @test write_trm_neural_optimizer_state(raw_path, optimizer_state) == raw_path
        @test occursin("\"input_weights\":", read(raw_path, String))
        @test write_trm_neural_optimizer_state_tsv(raw_tsv_path, optimizer_state) == raw_tsv_path
        restored_optimizer = read_trm_neural_optimizer_state_tsv(raw_tsv_path)
        @test restored_optimizer.model.input_weights == optimizer_state.model.input_weights
        @test restored_optimizer.model.hidden_bias == optimizer_state.model.hidden_bias
        @test restored_optimizer.model.output_weights == optimizer_state.model.output_weights
        @test restored_optimizer.model.output_bias == optimizer_state.model.output_bias
        @test restored_optimizer.loss_trace == optimizer_state.loss_trace
        @test restored_optimizer.epoch_trace == optimizer_state.epoch_trace
        @test restored_optimizer.summary.final_loss == optimizer_state.summary.final_loss
        checkpoint_certificate = trm_neural_optimizer_checkpoint_certificate(raw_tsv_path)
        @test checkpoint_certificate.ok
        certified_checkpoint = certified_trm_neural_optimizer_checkpoint(raw_tsv_path, certification)
        @test certified_checkpoint.payload.kind == :TRMNeuralOptimizerCheckpoint
        @test "read_trm_neural_optimizer_state_tsv" in
            certificate_dependency_graph(certified_checkpoint).julia_checkers
        @test write_certified_trm_neural_optimizer_state(
            certified_path,
            optimizer_state,
            certification,
        ) == certified_path
        @test occursin("\"certificate\":", read(certified_path, String))
    end

    mktempdir() do dir
        experiment = run_trm_neural_training_experiment(
            adapter,
            zeros(2),
            dc;
            consumer=TRMConsumer(program; steps=1),
            rollout_steps=2,
            hidden_dim=4,
            activation=:tanh,
            learning_rate=0.05,
            checkpoint_count=2,
            epochs_per_checkpoint=5,
            output_dir=dir,
            certificate_check=certification,
            eig_tol=1e-10,
        )
        @test experiment isa TRMNeuralTrainingExperimentResult
        @test experiment.summary.kind == :TRMNeuralTrainingExperiment
        @test experiment.summary.certified
        @test experiment.summary.sample_count == 2
        @test experiment.summary.checkpoint_count == 2
        @test experiment.training_run.summary.cumulative_epochs == 10
        @test isfile(experiment.artifact_paths.summary_path)
        @test isfile(experiment.artifact_paths.rollout_summary_path)
        @test isfile(experiment.artifact_paths.optimizer_path)
        @test isfile(experiment.artifact_paths.optimizer_state_tsv_path)
        @test isfile(experiment.artifact_paths.dataset_certificate_path)
        @test isfile(experiment.artifact_paths.training_run_certificate_path)
        @test isfile(experiment.artifact_paths.optimizer_certificate_path)
        @test isfile(experiment.artifact_paths.optimizer_checkpoint_certificate_path)
        @test occursin(
            "\"kind\":\"TRMNeuralTrainingExperiment\"",
            read(experiment.artifact_paths.summary_path, String),
        )
        @test occursin(
            "\"kind\":\"TRMNeuralTrainingRun\"",
            read(experiment.artifact_paths.training_run_certificate_path, String),
        )
        @test occursin(
            "\"certificate\":",
            read(experiment.artifact_paths.optimizer_certificate_path, String),
        )
        @test occursin(
            "\"kind\":\"TRMNeuralOptimizerCheckpoint\"",
            read(experiment.artifact_paths.optimizer_checkpoint_certificate_path, String),
        )
    end

    mktempdir() do dir
        sweep = run_trm_neural_training_experiment_sweep(
            adapter,
            zeros(2),
            dc;
            consumer=TRMConsumer(program; steps=1),
            rollout_steps=2,
            hidden_dims=[4],
            learning_rates=[0.04, 0.05],
            checkpoint_counts=[2],
            epochs_per_checkpoint_values=[5],
            output_dir=dir,
            certificate_check=certification,
            eig_tol=1e-10,
        )
        @test sweep isa TRMNeuralTrainingExperimentSweepResult
        @test sweep.summary.kind == :TRMNeuralTrainingExperimentSweep
        @test sweep.summary.run_count == 2
        @test length(sweep.experiments) == 2
        @test sweep.summary.best_index in (1, 2)
        @test isfile(sweep.artifact_paths.summary_path)
        @test isfile(sweep.artifact_paths.report_path)
        @test isfile(sweep.artifact_paths.certificate_graph_path)
        @test isfile(sweep.artifact_paths.report_certificate_path)
        @test isfile(joinpath(dir, "run-001", "summary.json"))
        @test isfile(joinpath(dir, "run-001", "run-summary.tsv"))
        @test isfile(joinpath(dir, "run-002", "summary.json"))
        @test isfile(joinpath(dir, "run-002", "run-summary.tsv"))
        @test occursin(
            "\"kind\":\"TRMNeuralTrainingExperimentSweep\"",
            read(sweep.artifact_paths.summary_path, String),
        )
        sweep_report = trm_neural_experiment_sweep_report(sweep)
        @test sweep_report.kind == :TRMNeuralTrainingExperimentSweepReport
        @test sweep_report.run_count == 2
        @test sweep_report.completed_run_count == 2
        @test sweep_report.missing_artifact_count == 0
        sweep_report_certificate = trm_neural_experiment_sweep_report_certificate(sweep_report)
        @test sweep_report_certificate.ok
        @test sweep_report_certificate.best_loss_ok
        certified_sweep_report = certified_trm_neural_experiment_sweep_report(
            sweep_report,
            certification,
        )
        @test certified_sweep_report.payload.kind ==
            :TRMNeuralTrainingExperimentSweepReport
        @test "trm_neural_experiment_sweep_report_certificate" in
            certificate_dependency_graph(certified_sweep_report).julia_checkers
        @test occursin(
            "\"kind\":\"TRMNeuralTrainingExperimentSweepReport\"",
            trm_neural_experiment_sweep_report_json(sweep),
        )
        @test occursin(
            "\"kind\":\"TRMNeuralTrainingExperimentSweepReport\"",
            certified_trm_neural_experiment_sweep_report_json(
                sweep_report,
                certification,
            ),
        )
        @test occursin(
            "\"artifact_complete\":true",
            read(sweep.artifact_paths.report_path, String),
        )
        @test occursin(
            "\"certificate\":",
            read(sweep.artifact_paths.report_certificate_path, String),
        )
        report_json_audit = certified_json_artifact_audit(
            sweep.artifact_paths.report_certificate_path;
            expected_kind=:TRMNeuralTrainingExperimentSweepReport,
        )
        @test report_json_audit.ok
        @test write_trm_neural_experiment_sweep_report(
            joinpath(dir, "manual-report.json"),
            sweep,
        ) == joinpath(dir, "manual-report.json")
        @test write_certified_trm_neural_experiment_sweep_report(
            joinpath(dir, "manual-report.certified.json"),
            sweep_report,
            certification,
        ) == joinpath(dir, "manual-report.certified.json")
        certificate_graph = trm_neural_experiment_sweep_certificate_graph(sweep)
        @test certificate_graph.kind == :TRMNeuralTrainingExperimentSweepCertificateGraph
        @test certificate_graph.run_count == 2
        @test certificate_graph.certificate_complete_count == 2
        @test certificate_graph.missing_certificate_count == 0
        @test certificate_graph.report_certificate_exists
        envelope_audit = trm_neural_experiment_sweep_certified_envelope_audit(sweep)
        @test envelope_audit.ok
        @test envelope_audit.audit_count == 9
        @test envelope_audit.failed_count == 0
        @test occursin(
            "\"kind\":\"TRMNeuralTrainingExperimentSweepCertificateGraph\"",
            trm_neural_experiment_sweep_certificate_graph_json(sweep),
        )
        @test occursin(
            "\"kind\":\"TRMNeuralTrainingExperimentSweepCertifiedEnvelopeAudit\"",
            trm_neural_experiment_sweep_certified_envelope_audit_json(sweep),
        )
        @test occursin(
            "\"relation\":\"has_certificate_artifact\"",
            read(sweep.artifact_paths.certificate_graph_path, String),
        )
        @test write_trm_neural_experiment_sweep_certificate_graph(
            joinpath(dir, "manual-certificate-graph.json"),
            sweep,
        ) == joinpath(dir, "manual-certificate-graph.json")
        @test write_trm_neural_experiment_sweep_certified_envelope_audit(
            joinpath(dir, "manual-envelope-audit.json"),
            sweep,
        ) == joinpath(dir, "manual-envelope-audit.json")
        directory_report = trm_neural_experiment_sweep_report(dir)
        @test directory_report.run_count == 2
        @test directory_report.completed_run_count == 2
        @test directory_report.best_final_loss == sweep.summary.best_final_loss
        directory_graph = trm_neural_experiment_sweep_certificate_graph(dir)
        @test directory_graph.run_count == 2
        @test directory_graph.certificate_complete_count == 2
        directory_audit = trm_neural_experiment_sweep_certified_envelope_audit(dir)
        @test directory_audit.ok
        @test directory_audit.audit_count == 9
        resumed_sweep = run_trm_neural_training_experiment_sweep(
            adapter,
            zeros(2),
            dc;
            consumer=TRMConsumer(program; steps=1),
            rollout_steps=2,
            hidden_dims=[4],
            learning_rates=[0.04, 0.05],
            checkpoint_counts=[2],
            epochs_per_checkpoint_values=[5],
            output_dir=dir,
            certificate_check=certification,
            resume=true,
            eig_tol=1e-10,
        )
        @test resumed_sweep.summary.run_count == 2
        @test resumed_sweep.summary.resumed_count == 2
        @test all(isnothing, resumed_sweep.experiments)
        @test resumed_sweep.summary.best_final_loss == sweep.summary.best_final_loss
        continued_sweep = run_trm_neural_training_experiment_sweep(
            adapter,
            zeros(2),
            dc;
            consumer=TRMConsumer(program; steps=1),
            rollout_steps=2,
            hidden_dims=[4],
            learning_rates=[0.04],
            checkpoint_counts=[3],
            epochs_per_checkpoint_values=[5],
            output_dir=dir,
            continue_from_optimizer=true,
            certificate_check=certification,
            eig_tol=1e-10,
        )
        @test continued_sweep.summary.run_count == 1
        @test continued_sweep.summary.entries[1].checkpoint_count == 3
        @test !continued_sweep.summary.entries[1].resumed
        continued_optimizer = read_trm_neural_optimizer_state_tsv(
            joinpath(dir, "run-001", "optimizer-state.tsv"),
        )
        @test continued_optimizer.summary.checkpoint_count == 3
        @test length(continued_optimizer.loss_trace) == 3
        @test length(continued_optimizer.epoch_trace) == 3
        @test continued_optimizer.model.epochs == 15
    end

    perfect_loss = trm_dataset_loss(
        [sample.target_action for sample in dataset.samples],
        dataset,
    )
    @test perfect_loss ≈ 0.0

    predictor_loss = trm_dataset_loss(
        observation -> observation.input_action,
        dataset,
    )
    @test predictor_loss >= 0.0
    @test trm_dataset_loss(
        [zeros(2), zeros(2)],
        dataset;
        weights=TRMLossWeights(action=1.0, world=0.1, slowing=0.0),
    ) >= 0.0
end
