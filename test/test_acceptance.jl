@testset "experiment acceptance" begin
    config = ExperimentAcceptanceConfig()
    @test config.lambda_threshold == 0.95
    @test config.eig_tol == 1e-6
    @test config.seed == 42
    @test config.repeats == 3
    @test config.relative_tolerance == 0.01

    stable = reproducibility_assessment([1.0, 1.005, 0.995]; config=config)
    @test stable.accepted
    @test stable.seed == 42
    @test stable.repeats == 3
    @test stable.max_relative_deviation <= 0.01

    unstable = reproducibility_assessment([1.0, 1.03, 0.97]; config=config)
    @test !unstable.accepted

    nonfinite = reproducibility_assessment([1.0, Inf, 1.0]; config=config)
    @test !nonfinite.accepted

    calls = Tuple{Int,Int}[]
    trials = run_reproducibility_trials(
        (seed, replicate) -> begin
            push!(calls, (seed, replicate))
            seed + replicate
        end;
        metric=Float64,
        config=config,
    )
    @test calls == [(42, 1), (42, 2), (42, 3)]
    @test trials.values == [43.0, 44.0, 45.0]
    @test trials.assessment.seed == 42
    @test !trials.assessment.accepted

    @test_throws ArgumentError reproducibility_assessment([1.0, 1.0]; config=config)
    @test_throws ArgumentError ExperimentAcceptanceConfig(repeats=1)
    @test_throws ArgumentError ExperimentAcceptanceConfig(relative_tolerance=-0.1)
end
