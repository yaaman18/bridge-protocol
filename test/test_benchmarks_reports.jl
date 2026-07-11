@testset "benchmarks collapse and reports" begin
    adapter = toy_recurrent_adapter(
        ToyRecurrentSystem(zeros(2, 2), [
            1.0 0.0
            0.0 1.0
        ]),
        [0.0, 0.0],
    )
    action = [0.0, 0.0]
    dc = DCResult(true, true, true, true, Set([:toy_act]))
    direction = [1.0, -1.0] / sqrt(2)

    benchmark = run_reference_benchmarks(
        adapter,
        action,
        dc;
        direction=direction,
        eig_tol=1e-10,
        fixed_tol=1e-10,
        action_index=1,
        interoceptive_signal=[0.1],
    )
    @test benchmark_passed(benchmark)
    @test [case.name for case in benchmark.cases] == [
        :computational_sanity,
        :adjunction_world_bridge,
        :blindsight_analog,
        :precariousness_slowing,
    ]

    trace = world_collapse_trace(
        adapter,
        [action, [10.0, 10.0]];
        eig_tol=1e-10,
    )
    @test length(trace.eigenvalues) == 2
    @test length(trace.dimensions) == 2
    @test world_dimension_series(trace).collapsed_at == trace.collapsed_at

    report = observation_structure_report(
        adapter,
        action,
        dc;
        direction=direction,
        eig_tol=1e-10,
        fixed_tol=1e-10,
        reachable_directions=direction,
        action_index=1,
        interoceptive_signal=[0.1],
        collapse_actions=[action, action],
    )
    @test report.pipeline.classification == :conscious
    @test benchmark_passed(report.benchmark)
    @test report.summary.benchmark_passed
    @test length(report.policy_action) == 2
    @test length(report.collapse.dimensions) == 2

    artifact = observation_artifact(report)
    @test haskey(artifact, :T)
    @test haskey(artifact, :Wld_projection)
    json = observation_artifact_json(report)
    @test occursin("\"T\":", json)
    @test occursin("\"Wld_projection\":", json)
    @test occursin("\"classification\":\"conscious\"", json)

    series_artifact = observation_series_artifact([report, report])
    @test length(series_artifact.frames) == 2
    @test occursin("\"frames\":", observation_series_artifact_json([report]))

    certification = verify_certified_artifact(
        parse_certified_artifact("ERIEC_CERTIFIED_ARTIFACT\t1\ttest-boundary\n"),
    )
    @test certified_artifact_ok(certification)
    certified_json = certified_observation_artifact_json(report, certification)
    @test occursin("\"payload\":", certified_json)
    @test occursin("\"certificate\":", certified_json)
    @test occursin("\"artifact_id\":\"test-boundary\"", certified_json)
    @test occursin("\"classification\":\"conscious\"", certified_json)
    @test occursin("\"frames\":", certified_observation_series_artifact_json([report], certification))

    mktempdir() do dir
        artifact_path = joinpath(dir, "observation.json")
        series_path = joinpath(dir, "series.json")
        certified_path = joinpath(dir, "certified-observation.json")
        certified_series_path = joinpath(dir, "certified-series.json")
        @test write_observation_artifact(artifact_path, report) == artifact_path
        @test write_observation_series_artifact(series_path, [report, report]) == series_path
        @test write_certified_observation_artifact(certified_path, report, certification) ==
            certified_path
        @test write_certified_observation_series_artifact(
            certified_series_path,
            [report, report],
            certification,
        ) == certified_series_path
        @test occursin("\"classification\":\"conscious\"", read(artifact_path, String))
        @test occursin("\"frames\":", read(series_path, String))
        @test occursin("\"certificate\":", read(certified_path, String))
        @test occursin("\"frames\":", read(certified_series_path, String))
        certified_audit = certified_json_artifact_audit(certified_path)
        @test certified_audit.ok
        @test certified_audit.parse_ok
        @test certified_audit.parse_error === nothing

        malformed_path = joinpath(dir, "malformed.json")
        open(malformed_path, "w") do io
            write(io, "{\"payload\":")
        end
        malformed_audit = certified_json_artifact_audit(malformed_path)
        @test !malformed_audit.ok
        @test !malformed_audit.parse_ok
        @test malformed_audit.parse_error !== nothing

        spoofed_path = joinpath(dir, "spoofed.json")
        open(spoofed_path, "w") do io
            write(io, "{\"text\":\"\\\"schema_version\\\":1 ")
            write(io, "\\\"payload\\\":{} \\\"certificate\\\":{} ")
            write(io, "\\\"trust\\\":{} \\\"ok\\\":true\"}")
        end
        spoofed_audit = certified_json_artifact_audit(spoofed_path)
        @test !spoofed_audit.ok
        @test spoofed_audit.parse_ok
        @test !spoofed_audit.payload_ok
    end
end
