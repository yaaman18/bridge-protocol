using Test
using ERIEC

@testset "Sigma selection contract" begin
    candidates = [
        QDCandidate(:a, 0.1, 1, 2.0, true, true, true),
        QDCandidate(:b, 0.1, 1, 3.0, true, true, true),
        QDCandidate(:c, 0.9, 9, 8.0, false, true, true),
    ]
    selected = qd_selection_step(candidates; diversity_upper=1.0)
    @test selected.admitted == 2
    @test selected.rejected == 1
    @test length(selected.archive.cells) == 1
    @test only(values(selected.archive.cells)).individual == :b

    null_step = qd_selection_step(candidates; diversity_upper=1.0, null_selection=true)
    @test null_step.admitted == 2
    @test length(null_step.archive.cells) == 1

    pure = SigmaPurityExperiment([1, 2], (individual, _selector) -> (individual, individual + 1))
    pure_result = check_sigma_purity(pure)
    @test pure_result.valid
    @test pure_result.static_ok
    @test pure_result.dynamic_ok

    impure = SigmaPurityExperiment([1], (individual, selector) ->
        (individual, selector.archive_seed))
    impure_result = check_sigma_purity(impure)
    @test !impure_result.valid
    @test !impure_result.dynamic_ok

    selected_metrics = (
        depth_max=collect(21.0:30.0),
        depth_mean=collect(11.0:20.0),
        diversity_median=collect(31.0:40.0),
    )
    null_metrics = (
        depth_max=collect(1.0:10.0),
        depth_mean=collect(1.0:10.0),
        diversity_median=collect(11.0:20.0),
    )
    nondegenerate = check_selection_nondegenerate(selected_metrics, null_metrics)
    @test nondegenerate.holds
    @test nondegenerate.depth.p <= 0.025
    @test nondegenerate.depth.delta == 1.0
    @test nondegenerate.diversity.holds

    plan = run_sigma1_experiment(replicate=0)
    @test plan.seed == 20260720
    @test plan.grid == (8, 8)
    @test plan.batch_size == 16
    @test plan.generations == 200
    @test plan.reference_sizes == (2, 3, 8, 32)
    @test plan.initial_population == 64
    @test plan.preregistered_rules == (:R1, :R2, :R3, :R4)
    @test_throws ArgumentError run_sigma1_experiment(replicate=10)
end
