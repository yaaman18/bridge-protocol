@testset "Lenia report CLI" begin
    options = parse_lenia_report_args([
        "--shape", "3x3",
        "--action-count", "2",
        "--feature-count", "6",
        "--kernel-size", "3",
        "--tau-steps", "1,2",
        "--seed", "7",
        "--repeats", "4",
        "--relative-tolerance", "0.02",
        "--lambda-threshold", "0.9",
        "--initial-mode", "uniform_noise",
        "--initial-baseline", "0.5",
        "--initial-amplitude", "0.02",
        "--initial-width", "0.3",
        "--output", "-",
    ])
    @test options.shape == (3, 3)
    @test options.preset === nothing
    @test options.preset_file === nothing
    @test options.action_count == 2
    @test options.feature_count == 6
    @test options.feature_counts == [6]
    @test options.kernel_size == 3
    @test options.tau_steps == [1, 2]
    @test options.seed == 7
    @test options.repeats == 4
    @test options.relative_tolerance == 0.02
    @test options.lambda_threshold == 0.9
    @test options.initial_mode == :uniform_noise
    @test options.initial_baseline == 0.5
    @test options.initial_amplitude == 0.02
    @test options.initial_width == 0.3
    @test !options.resume
    @test !options.certified
    @test options.run_indices === nothing
    @test !options.dry_run
    @test options.output == "-"
    @test options.output_dir === nothing

    grid_options = parse_lenia_report_args([
        "--shape", "3x3",
        "--action-count", "2",
        "--feature-counts", "6,32",
        "--kernel-size", "3",
        "--tau-steps", "1,2",
        "--output", "-",
    ])
    @test grid_options.feature_count == 6
    @test grid_options.feature_counts == [6, 32]

    managed_options = parse_lenia_report_args([
        "--preset", "short",
        "--tau-steps", "1",
    ])
    @test managed_options.preset == :short
    @test managed_options.shape == (8, 8)
    @test managed_options.action_count == 16
    @test managed_options.feature_counts == [6, 32]
    @test managed_options.tau_steps == [1]
    @test_throws ArgumentError parse_lenia_report_args(["--resume"])
    @test_throws ArgumentError parse_lenia_report_args(["--dry-run"])

    planned_options = parse_lenia_report_args([
        "--preset", "short",
        "--run-indices", "2,4",
        "--dry-run",
    ])
    @test planned_options.run_indices == [2, 4]
    @test planned_options.dry_run

    mktempdir() do dir
        preset_path = joinpath(dir, "custom-lenia.tsv")
        open(preset_path, "w") do io
            println(io, "name\tcustom")
            println(io, "shape\t4x4")
            println(io, "action_count\t3")
            println(io, "feature_counts\t6")
            println(io, "kernel_size\t3")
            println(io, "tau_steps\t1,2")
            println(io, "repeats\t2")
            println(io, "initial_mode\tgaussian_blob")
            println(io, "initial_amplitude\t0.8")
        end
        file_options = parse_lenia_report_args([
            "--preset-file", preset_path,
            "--tau-steps", "4",
        ])
        @test file_options.preset == :custom
        @test file_options.preset_file == preset_path
        @test file_options.shape == (4, 4)
        @test file_options.repeats == 2
        @test file_options.initial_mode == :gaussian_blob
        @test file_options.initial_amplitude == 0.8
        @test file_options.tau_steps == [4]
    end

    help_io = IOBuffer()
    @test run_lenia_report_cli(["--help"]; stdout=help_io) == 0
    @test occursin("Usage: eriec-lenia-report", String(take!(help_io)))

    error_io = IOBuffer()
    @test run_lenia_report_cli(["--feature-count", "7"]; stderr=error_io) == 2
    @test occursin("feature-count", String(take!(error_io)))

    mktempdir() do dir
        plan_dir = joinpath(dir, "plan")
        plan_io = IOBuffer()
        rc = run_lenia_report_cli([
            "--preset", "short",
            "--run-indices", "2,4",
            "--dry-run",
            "--certified",
            "--initial-mode", "uniform_noise",
            "--initial-baseline", "0.5",
            "--initial-amplitude", "0.01",
            "--output-dir", plan_dir,
        ]; stdout=plan_io)
        @test rc == 0
        @test occursin("\"mode\":\"experiment_plan\"", String(take!(plan_io)))
        plan_json = read(joinpath(plan_dir, "plan.json"), String)
        @test occursin("\"selected_condition_count\":2", plan_json)
        @test occursin("\"selected_architecture_runs\":6", plan_json)
        @test occursin("\"mode\":\"uniform_noise\"", plan_json)
        @test !isdir(joinpath(plan_dir, "run-002"))
    end

    mktempdir() do dir
        output_dir = joinpath(dir, "managed")
        summary_io = IOBuffer()
        rc = run_lenia_report_cli([
            "--preset", "smoke",
            "--repeats", "2",
            "--output-dir", output_dir,
            "--certified",
        ]; stdout=summary_io)
        @test rc == 0
        @test occursin("\"mode\":\"experiment_sweep\"", String(take!(summary_io)))
        @test isfile(joinpath(output_dir, "manifest.json"))
        @test isfile(joinpath(output_dir, "run-001", "summary.tsv"))
        @test isfile(joinpath(output_dir, "run-001", "certificate.json"))
        @test isfile(joinpath(output_dir, "certificate-graph.json"))

        resumed_io = IOBuffer()
        rc = run_lenia_report_cli([
            "--preset", "smoke",
            "--repeats", "2",
            "--output-dir", output_dir,
            "--resume",
            "--certified",
        ]; stdout=resumed_io)
        @test rc == 0
        @test occursin("\"resumed_count\":1", String(take!(resumed_io)))
    end

    mktempdir() do dir
        artifact_path = joinpath(dir, "lenia.json")
        summary_io = IOBuffer()
        rc = run_lenia_report_cli([
            "--shape", "3x3",
            "--action-count", "2",
            "--feature-count", "6",
            "--kernel-size", "3",
            "--tau-steps", "1",
            "--output", artifact_path,
        ]; stdout=summary_io)
        @test rc == 0
        @test occursin("\"mode\":\"single\"", String(take!(summary_io)))
        artifact = read(artifact_path, String)
        @test occursin("\"schema_version\":1", artifact)
        @test occursin("\"phenomenal_claim\":\"not_certified\"", artifact)
        @test occursin("\"reproducibility\":", artifact)
    end

    mktempdir() do dir
        artifact_path = joinpath(dir, "lenia-grid.json")
        summary_io = IOBuffer()
        rc = run_lenia_report_cli([
            "--shape", "3x3",
            "--action-count", "2",
            "--feature-counts", "6",
            "--kernel-size", "3",
            "--tau-steps", "1,2",
            "--output", artifact_path,
        ]; stdout=summary_io)
        @test rc == 0
        @test occursin("\"mode\":\"series\"", String(take!(summary_io)))
        @test occursin("\"artifacts\":", read(artifact_path, String))
    end

    mktempdir() do dir
        artifact_path = joinpath(dir, "lenia-grid.json")
        summary_io = IOBuffer()
        rc = run_lenia_report_cli([
            "--shape", "3x3",
            "--action-count", "2",
            "--feature-counts", "6,32",
            "--kernel-size", "3",
            "--tau-steps", "1",
            "--output", artifact_path,
        ]; stdout=summary_io)
        @test rc == 0
        @test occursin("\"mode\":\"parameter_grid\"", String(take!(summary_io)))
        @test occursin("\"artifacts\":", read(artifact_path, String))
    end

    mktempdir() do dir
        output_dir = joinpath(dir, "run")
        summary_io = IOBuffer()
        rc = run_lenia_report_cli([
            "--shape", "3x3",
            "--action-count", "2",
            "--feature-count", "6",
            "--kernel-size", "3",
            "--tau-steps", "1",
            "--output-dir", output_dir,
        ]; stdout=summary_io)
        @test rc == 0
        @test occursin("\"summary_path\":", String(take!(summary_io)))
        @test isfile(joinpath(output_dir, "artifact.json"))
        @test isfile(joinpath(output_dir, "summary.json"))
        @test occursin(
            "\"phenomenal_claim\":\"not_certified\"",
            read(joinpath(output_dir, "artifact.json"), String),
        )
        @test occursin("\"mode\":\"single\"", read(joinpath(output_dir, "summary.json"), String))
    end
end

@testset "TRM neural experiment CLI" begin
    options = parse_trm_neural_experiment_args([
        "--system", "toy",
        "--action-count", "2",
        "--rollout-steps", "2",
        "--hidden-dims", "4",
        "--learning-rates", "0.05",
        "--checkpoint-counts", "2",
        "--epochs-per-checkpoint", "5",
    ])
    @test options.system == :toy
    @test options.preset == :smoke
    @test options.action_count == 2
    @test options.rollout_steps == 2
    @test options.hidden_dims == [4]
    @test options.learning_rates == [0.05]
    @test options.checkpoint_counts == [2]
    @test options.epochs_per_checkpoint_values == [5]
    @test !options.resume
    @test !options.continue_from_optimizer
    @test !options.certified

    preset_options = parse_trm_neural_experiment_args([
        "--preset", "short",
    ])
    @test preset_options.preset == :short
    @test length(preset_options.hidden_dims) > 1
    @test length(preset_options.learning_rates) > 1

    mktempdir() do dir
        preset_path = joinpath(dir, "custom-trm-preset.tsv")
        open(preset_path, "w") do io
            println(io, "name\tcustom")
            println(io, "system\ttoy")
            println(io, "rollout_steps\t3")
            println(io, "hidden_dims\t4,6")
            println(io, "learning_rates\t0.03")
            println(io, "checkpoint_counts\t2")
            println(io, "epochs_per_checkpoint\t5")
            println(io, "certified\tfalse")
        end
        loaded_preset = read_trm_neural_experiment_preset(preset_path)
        @test loaded_preset.name == :custom
        @test loaded_preset.hidden_dims == [4, 6]
        file_options = parse_trm_neural_experiment_args([
            "--preset-file", preset_path,
            "--hidden-dims", "8",
        ])
        @test file_options.preset == :custom
        @test file_options.preset_file == preset_path
        @test file_options.rollout_steps == 3
        @test file_options.hidden_dims == [8]
        @test file_options.learning_rates == [0.03]
    end

    help_io = IOBuffer()
    @test run_trm_neural_experiment_cli(["--help"]; stdout=help_io) == 0
    @test occursin("Usage: eriec-trm-neural-experiment", String(take!(help_io)))

    error_io = IOBuffer()
    @test run_trm_neural_experiment_cli(["--system", "bad"]; stderr=error_io) == 2
    @test occursin("system must be toy or lenia", String(take!(error_io)))

    mktempdir() do dir
        output_dir = joinpath(dir, "single")
        summary_io = IOBuffer()
        rc = run_trm_neural_experiment_cli([
            "--system", "toy",
            "--preset", "smoke",
            "--action-count", "2",
            "--rollout-steps", "2",
            "--hidden-dims", "4",
            "--learning-rates", "0.05",
            "--checkpoint-counts", "2",
            "--epochs-per-checkpoint", "5",
            "--output-dir", output_dir,
        ]; stdout=summary_io)
        @test rc == 0
        @test occursin("\"mode\":\"single\"", String(take!(summary_io)))
        @test isfile(joinpath(output_dir, "summary.json"))
        @test isfile(joinpath(output_dir, "optimizer.json"))
        @test isfile(joinpath(output_dir, "run-summary.tsv"))
    end

    mktempdir() do dir
        output_dir = joinpath(dir, "sweep")
        summary_io = IOBuffer()
        rc = run_trm_neural_experiment_cli([
            "--system", "toy",
            "--action-count", "2",
            "--rollout-steps", "2",
            "--hidden-dims", "4",
            "--learning-rates", "0.04,0.05",
            "--checkpoint-counts", "2",
            "--epochs-per-checkpoint", "5",
            "--output-dir", output_dir,
        ]; stdout=summary_io)
        @test rc == 0
        @test occursin("\"mode\":\"sweep\"", String(take!(summary_io)))
        @test isfile(joinpath(output_dir, "summary.json"))
        @test isfile(joinpath(output_dir, "run-001", "run-summary.tsv"))
        @test isfile(joinpath(output_dir, "run-002", "run-summary.tsv"))

        resumed_io = IOBuffer()
        rc = run_trm_neural_experiment_cli([
            "--system", "toy",
            "--action-count", "2",
            "--rollout-steps", "2",
            "--hidden-dims", "4",
            "--learning-rates", "0.04,0.05",
            "--checkpoint-counts", "2",
            "--epochs-per-checkpoint", "5",
            "--output-dir", output_dir,
            "--resume",
            "--continue",
        ]; stdout=resumed_io)
        @test rc == 0
        @test occursin("\"resumed_count\":2", String(take!(resumed_io)))

        continued_io = IOBuffer()
        rc = run_trm_neural_experiment_cli([
            "--system", "toy",
            "--action-count", "2",
            "--rollout-steps", "2",
            "--hidden-dims", "4",
            "--learning-rates", "0.04",
            "--checkpoint-counts", "3",
            "--epochs-per-checkpoint", "5",
            "--output-dir", output_dir,
            "--continue",
        ]; stdout=continued_io)
        @test rc == 0
        @test occursin("\"checkpoint_count\":3", String(take!(continued_io)))
        restored = read_trm_neural_optimizer_state_tsv(
            joinpath(output_dir, "optimizer-state.tsv"),
        )
        @test restored.summary.checkpoint_count == 3
    end
end
