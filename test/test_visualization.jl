@testset "experiment visualization" begin
    trace = CollapseTraceResult(
        [[0.0], [0.5], [1.0]],
        [0.98, 0.95, 0.72],
        [3, 2, 0],
        [50.0, 20.0, 3.5],
        3,
    )
    collapse_html = collapse_trace_dashboard_html(trace; title="Wld <collapse>")
    @test startswith(collapse_html, "<!doctype html>")
    @test occursin("Wld &lt;collapse&gt;", collapse_html)
    @test occursin("Dominant eigenvalue", collapse_html)
    @test occursin("Wld dimension", collapse_html)
    @test occursin("Critical slowing score", collapse_html)
    @test occursin("<polyline", collapse_html)
    @test occursin("name=\"viewport\"", collapse_html)

    report = (
        kind=:LeniaExperimentSweepReport,
        output_dir=nothing,
        preset=:smoke,
        run_count=2,
        accepted_count=1,
        resumed_count=0,
        artifact_complete_count=1,
        missing_artifact_count=1,
        invalid_artifact_count=1,
        invalid_certificate_count=1,
        invalid_summary_count=1,
        entries=[
            (
                index=1,
                tau_step=1,
                feature_count=6,
                dominant_eigenvalue=0.98,
                max_relative_deviation=0.001,
                status=:architecture_warn,
                accepted=true,
                artifact_exists=true,
                artifact_valid=true,
                certified=true,
                certificate_exists=true,
                certificate_valid=true,
            ),
            (
                index=2,
                tau_step=2,
                feature_count=32,
                dominant_eigenvalue=0.81,
                max_relative_deviation=0.02,
                status=:architecture_reject,
                accepted=false,
                artifact_exists=true,
                artifact_valid=false,
                certified=true,
                certificate_exists=true,
                certificate_valid=false,
            ),
        ],
    )
    sweep_html = lenia_experiment_dashboard_html(report)
    @test occursin("Lenia experiment dashboard", sweep_html)
    @test occursin("Dominant Wld eigenvalue by run", sweep_html)
    @test occursin("Reproducibility deviation by run", sweep_html)
    @test occursin("architecture_reject", sweep_html)
    @test occursin("Invalid artifacts", sweep_html)
    @test occursin("Invalid certificates", sweep_html)
    @test occursin("Invalid summaries", sweep_html)
    @test occursin(">invalid</td>", sweep_html)
    @test occursin("<th>Certificate</th>", sweep_html)

    adapter = toy_recurrent_adapter(
        ToyRecurrentSystem(zeros(2, 2), [1.0 0.0; 0.0 1.0]),
        zeros(2),
    )
    observation = observation_structure_report(
        adapter,
        zeros(2),
        DCResult(true, true, true, true, Set([:visualization]));
        direction=[1.0, -1.0] / sqrt(2),
        eig_tol=1e-10,
        fixed_tol=1e-10,
        reachable_directions=[1.0, -1.0],
        interoceptive_signal=[0.1],
    )
    observation_html = observation_series_dashboard_html([observation, observation])
    @test occursin("ERIE observation tensor series", observation_html)
    @test occursin("Sensitivity norm ||T||", observation_html)
    @test occursin("Latest sensitivity tensor T", observation_html)
    @test occursin("Latest viability tensor V", observation_html)
    @test occursin("Latest weighted tensor O_hat", observation_html)
    @test occursin("<rect", observation_html)

    mktempdir() do dir
        collapse_path = joinpath(dir, "collapse.html")
        sweep_path = joinpath(dir, "sweep.html")
        observation_path = joinpath(dir, "observation.html")
        @test write_collapse_trace_dashboard(collapse_path, trace) == collapse_path
        @test write_lenia_experiment_dashboard(sweep_path, report) == sweep_path
        @test write_observation_series_dashboard(
            observation_path,
            [observation],
        ) == observation_path
        @test isfile(collapse_path)
        @test isfile(sweep_path)
        @test isfile(observation_path)
    end
end
