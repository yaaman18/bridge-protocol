@testset "Lenia experiment management" begin
    catalog = lenia_experiment_preset_catalog()
    @test catalog.smoke.name == :smoke
    @test catalog.short.action_count == 16
    @test catalog.long.action_count == 24
    @test catalog.smoke.initial_condition.mode == :zeros
    @test length(catalog.long.tau_steps) > length(catalog.short.tau_steps)
    @test lenia_experiment_preset(:smoke).name == catalog.smoke.name
    @test_throws ArgumentError lenia_experiment_preset(:missing)

    certificate = lenia_experiment_preset_certificate(catalog.smoke)
    @test certificate.ok
    @test certificate.kind == :LeniaExperimentPreset
    @test certificate.condition_count == 1
    @test !certificate.production_action_dimension

    short_plan = lenia_experiment_plan(catalog.short; run_indices=[2, 3])
    @test short_plan.total_condition_count == 6
    @test short_plan.selected_condition_count == 2
    @test short_plan.selected_run_indices == [2, 3]
    @test short_plan.total_architecture_runs == 18
    @test short_plan.selected_architecture_runs == 6
    @test short_plan.conditions[1].tau_step == 1
    @test short_plan.conditions[1].feature_count == 32
    @test short_plan.conditions[2].tau_step == 2
    @test short_plan.conditions[2].feature_count == 6
    @test_throws ArgumentError lenia_experiment_plan(catalog.short; run_indices=Int[])
    @test_throws ArgumentError lenia_experiment_plan(catalog.short; run_indices=[1, 1])
    @test_throws ArgumentError lenia_experiment_plan(catalog.short; run_indices=[7])

    @test_throws ArgumentError LeniaExperimentPreset(
        :invalid,
        (3, 3),
        2,
        [7],
        3,
        [1],
        ExperimentAcceptanceConfig(),
        "invalid feature count",
    )

    mktempdir() do dir
        preset_path = joinpath(dir, "external.tsv")
        open(preset_path, "w") do io
            println(io, "name\texternal")
            println(io, "shape\t4x5")
            println(io, "action_count\t4")
            println(io, "feature_counts\t6,32")
            println(io, "kernel_size\t3")
            println(io, "tau_steps\t1,3")
            println(io, "seed\t7")
            println(io, "repeats\t2")
            println(io, "relative_tolerance\t0.02")
            println(io, "lambda_threshold\t0.9")
            println(io, "initial_mode\tuniform_noise")
            println(io, "initial_baseline\t0.5")
            println(io, "initial_amplitude\t0.02")
            println(io, "initial_width\t0.3")
        end
        external = read_lenia_experiment_preset(preset_path)
        @test external.name == :external
        @test external.shape == (4, 5)
        @test external.feature_counts == [6, 32]
        @test external.tau_steps == [1, 3]
        @test external.acceptance.seed == 7
        @test external.acceptance.repeats == 2
        @test external.acceptance.relative_tolerance == 0.02
        @test external.acceptance.lambda_threshold == 0.9
        @test external.initial_condition.mode == :uniform_noise
        @test external.initial_condition.baseline == 0.5
        @test external.initial_condition.amplitude == 0.02
        @test external.initial_condition.width == 0.3
    end

    acceptance = ExperimentAcceptanceConfig(repeats=2)
    certification = verify_lean_certified_artifact()
    mktempdir() do dir
        sweep = run_lenia_experiment_sweep(
            catalog.smoke;
            output_dir=dir,
            acceptance_config=acceptance,
            certificate_check=certification,
            run_indices=[1],
        )
        @test sweep.summary.run_count == 1
        @test sweep.summary.accepted_count == 1
        @test sweep.summary.resumed_count == 0
        @test sweep.summary.total_condition_count == 1
        @test sweep.summary.selected_run_indices == [1]
        @test sweep.summary.selected_architecture_runs == 2
        @test length(sweep.experiments) == 1
        @test !isnothing(first(sweep.experiments))
        @test isfile(sweep.artifact_paths.summary_path)
        @test isfile(sweep.artifact_paths.manifest_path)
        @test isfile(joinpath(dir, "run-001", "artifact.json"))
        @test isfile(joinpath(dir, "run-001", "summary.tsv"))
        @test occursin(
            "initial_mode\tzeros",
            read(joinpath(dir, "run-001", "summary.tsv"), String),
        )
        @test occursin(
            "system_fingerprint\t",
            read(joinpath(dir, "run-001", "summary.tsv"), String),
        )
        @test occursin(
            "artifact_sha256\t",
            read(joinpath(dir, "run-001", "summary.tsv"), String),
        )
        @test isfile(joinpath(dir, "run-001", "certificate.json"))
        @test isfile(sweep.artifact_paths.certificate_graph_path)
        @test isfile(sweep.artifact_paths.envelope_audit_path)
        @test isfile(sweep.artifact_paths.dashboard_path)
        @test occursin(
            "Lenia experiment dashboard",
            read(sweep.artifact_paths.dashboard_path, String),
        )
        @test occursin(
            "\"kind\":\"LeniaExperimentSweepManifest\"",
            read(sweep.artifact_paths.manifest_path, String),
        )
        @test occursin(
            "\"reproducibility\":",
            read(joinpath(dir, "run-001", "artifact.json"), String),
        )
        report = lenia_experiment_sweep_report(sweep)
        @test report.run_count == 1
        @test report.artifact_complete_count == 1
        @test report.missing_artifact_count == 0
        @test report.invalid_artifact_count == 0
        @test report.invalid_certificate_count == 0
        @test report.invalid_summary_count == 0
        @test report.entries[1].artifact_valid
        @test report.entries[1].certificate_valid
        @test report.entries[1].summary_valid
        @test lenia_experiment_summary_audit(
            joinpath(dir, "run-001", "summary.json"),
            report.entries[1],
        ).ok
        @test occursin(
            "\"kind\":\"LeniaExperimentSummaryAudit\"",
            lenia_experiment_summary_audit_json(
                joinpath(dir, "run-001", "summary.json"),
                report.entries[1],
            ),
        )
        artifact_path = joinpath(dir, "run-001", "artifact.json")
        artifact_audit = lenia_observation_artifact_audit(artifact_path)
        @test artifact_audit.ok
        @test artifact_audit.parse_ok
        @test artifact_audit.phenomenal_claim_ok
        @test artifact_audit.certified_envelope
        @test artifact_audit.envelope_ok
        @test artifact_audit.artifact_count == 1
        @test artifact_audit.artifact_count_ok
        @test_throws ArgumentError lenia_observation_artifact_audit(
            artifact_path;
            expected_artifact_count=0,
        )
        @test_throws ArgumentError lenia_observation_artifact_audit(
            artifact_path;
            eigenvalue_tolerance=-1.0,
        )
        @test occursin(
            "\"kind\":\"LeniaObservationArtifactAudit\"",
            lenia_observation_artifact_audit_json(artifact_path),
        )
        @test occursin(
            "\"kind\":\"LeniaExperimentSweepReport\"",
            lenia_experiment_sweep_report_json(sweep),
        )
        report_path = joinpath(dir, "manual-report.json")
        @test write_lenia_experiment_sweep_report(report_path, sweep) == report_path
        @test isfile(report_path)
        certificate_graph = lenia_experiment_sweep_certificate_graph(sweep)
        @test certificate_graph.run_count == 1
        @test certificate_graph.certification_requested_count == 1
        @test certificate_graph.certificate_complete_count == 1
        @test certificate_graph.missing_certificate_count == 0
        @test occursin(
            "\"kind\":\"LeniaExperimentSweepCertificateGraph\"",
            lenia_experiment_sweep_certificate_graph_json(sweep),
        )
        graph_path = joinpath(dir, "manual-certificate-graph.json")
        @test write_lenia_experiment_sweep_certificate_graph(graph_path, sweep) == graph_path
        envelope_audit = lenia_experiment_sweep_certified_envelope_audit(sweep)
        @test envelope_audit.ok
        @test envelope_audit.requested_count == 1
        @test envelope_audit.audit_count == 1
        @test envelope_audit.failed_count == 0
        @test occursin(
            "\"kind\":\"LeniaExperimentSweepCertifiedEnvelopeAudit\"",
            lenia_experiment_sweep_certified_envelope_audit_json(sweep),
        )
        audit_path = joinpath(dir, "manual-envelope-audit.json")
        @test write_lenia_experiment_sweep_certified_envelope_audit(
            audit_path,
            sweep,
        ) == audit_path

        original_artifact = read(artifact_path, String)
        tampered_artifact = replace(
            original_artifact,
            "not_certified" => "certified";
            count=1,
        )
        open(artifact_path, "w") do io
            write(io, tampered_artifact)
        end
        tampered_audit = lenia_observation_artifact_audit(artifact_path)
        @test !tampered_audit.ok
        @test !tampered_audit.parse_ok
        @test !isnothing(tampered_audit.parse_error)
        tampered_report = lenia_experiment_sweep_report(dir)
        @test tampered_report.artifact_complete_count == 0
        @test tampered_report.invalid_artifact_count == 1
        @test "artifact_invalid" in tampered_report.entries[1].missing_artifacts
        open(artifact_path, "w") do io
            write(io, original_artifact)
        end

        whitespace_modified_artifact = chomp(original_artifact) * " \n"
        open(artifact_path, "w") do io
            write(io, whitespace_modified_artifact)
        end
        checksum_report = lenia_experiment_sweep_report(dir)
        @test checksum_report.entries[1].artifact_audit.parse_ok
        @test !checksum_report.entries[1].artifact_audit.sha256_ok
        @test !checksum_report.entries[1].artifact_valid
        open(artifact_path, "w") do io
            write(io, original_artifact)
        end

        expected_fingerprint = report.entries[1].system_fingerprint
        mismatched_fingerprint_artifact = replace(
            original_artifact,
            expected_fingerprint => repeat("0", length(expected_fingerprint));
            count=1,
        )
        open(artifact_path, "w") do io
            write(io, mismatched_fingerprint_artifact)
        end
        fingerprint_report = lenia_experiment_sweep_report(dir)
        @test !fingerprint_report.entries[1].artifact_valid
        @test !fingerprint_report.entries[1].artifact_audit.system_fingerprint_ok
        @test "artifact_invalid" in fingerprint_report.entries[1].missing_artifacts
        open(artifact_path, "w") do io
            write(io, original_artifact)
        end

        summary_tsv_path = joinpath(dir, "run-001", "summary.tsv")
        original_summary_tsv = read(summary_tsv_path, String)
        tampered_summary_tsv = replace(
            original_summary_tsv,
            r"dominant_eigenvalue\t[^\n]+" => "dominant_eigenvalue\t999.0";
            count=1,
        )
        open(summary_tsv_path, "w") do io
            write(io, tampered_summary_tsv)
        end
        eigenvalue_report = lenia_experiment_sweep_report(dir)
        @test !eigenvalue_report.entries[1].artifact_valid
        @test !eigenvalue_report.entries[1].artifact_audit.dominant_eigenvalue_ok
        @test "artifact_invalid" in eigenvalue_report.entries[1].missing_artifacts
        open(summary_tsv_path, "w") do io
            write(io, original_summary_tsv)
        end

        summary_json_path = joinpath(dir, "run-001", "summary.json")
        original_summary_json = read(summary_json_path, String)
        tampered_summary_json = replace(
            original_summary_json,
            r"\"dominant_eigenvalue\":[^,}]+" => "\"dominant_eigenvalue\":999.0";
            count=1,
        )
        open(summary_json_path, "w") do io
            write(io, tampered_summary_json)
        end
        summary_report = lenia_experiment_sweep_report(dir)
        @test !summary_report.entries[1].summary_valid
        @test :dominant_eigenvalue in
            summary_report.entries[1].summary_audit.mismatched_fields
        @test "summary_invalid" in summary_report.entries[1].missing_artifacts
        open(summary_json_path, "w") do io
            write(io, original_summary_json)
        end

        untrusted_artifact = replace(
            original_artifact,
            "lean_core_julia_shell" => "untrusted_shell";
            count=1,
        )
        open(artifact_path, "w") do io
            write(io, untrusted_artifact)
        end
        untrusted_artifact_audit = lenia_observation_artifact_audit(artifact_path)
        @test !untrusted_artifact_audit.ok
        @test untrusted_artifact_audit.parse_ok
        @test !untrusted_artifact_audit.envelope_ok
        @test !lenia_experiment_sweep_report(dir).entries[1].artifact_valid
        open(artifact_path, "w") do io
            write(io, original_artifact)
        end

        run_certificate_path = joinpath(dir, "run-001", "certificate.json")
        original_certificate = read(run_certificate_path, String)
        tampered_certificate = replace(
            original_certificate,
            "lean_core_julia_shell" => "untrusted_shell";
            count=1,
        )
        open(run_certificate_path, "w") do io
            write(io, tampered_certificate)
        end
        invalid_certificate_report = lenia_experiment_sweep_report(dir)
        @test invalid_certificate_report.artifact_complete_count == 0
        @test invalid_certificate_report.invalid_certificate_count == 1
        @test !invalid_certificate_report.entries[1].certificate_valid
        @test "certificate_invalid" in
            invalid_certificate_report.entries[1].missing_artifacts
        open(run_certificate_path, "w") do io
            write(io, original_certificate)
        end

        resumed = run_lenia_experiment_sweep(
            catalog.smoke;
            output_dir=dir,
            acceptance_config=acceptance,
            certificate_check=certification,
            resume=true,
            run_indices=[1],
        )
        @test resumed.summary.run_count == 1
        @test resumed.summary.accepted_count == 1
        @test resumed.summary.resumed_count == 1
        @test isnothing(first(resumed.experiments))
        @test resumed.summary.entries[1].dominant_eigenvalue ==
            sweep.summary.entries[1].dominant_eigenvalue

        directory_report = lenia_experiment_sweep_report(dir)
        @test directory_report.run_count == 1
        @test directory_report.artifact_complete_count == 1
        @test directory_report.invalid_artifact_count == 0
        @test directory_report.invalid_certificate_count == 0
        @test directory_report.invalid_summary_count == 0
        @test lenia_experiment_sweep_certificate_graph(dir).certificate_complete_count == 1
        @test lenia_experiment_sweep_certified_envelope_audit(dir).ok
        rm(joinpath(dir, "run-001", "artifact.json"))
        incomplete_report = lenia_experiment_sweep_report(dir)
        @test incomplete_report.artifact_complete_count == 0
        @test incomplete_report.missing_artifact_count == 1
        @test incomplete_report.invalid_artifact_count == 0
        @test incomplete_report.invalid_certificate_count == 0
        @test incomplete_report.invalid_summary_count == 0
        @test "artifact_path" in incomplete_report.entries[1].missing_artifacts
    end
end
