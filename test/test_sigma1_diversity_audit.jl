using Test
using ERIEC

@testset "Sigma1 diversity resolution audit" begin
    population = sigma1_initial_population(0)
    traces_before = sigma1_observe_trace.(population)
    audit = check_sigma1_diversity_resolution(population)

    @test audit["pure"]
    @test audit["individuals"] == 64
    @test audit["within_size_finite"]
    @test 0 < audit["cap_replaced"] < 64
    @test 0.0 < audit["cap_fraction"] < 1.0
    @test Set(stats["size"] for stats in audit["by_size"]) == Set((2, 3, 8, 32))
    @test all(stats -> stats["pairs"] > 0, audit["by_size"])
    @test all(stats -> stats["pair_iqr"] >= 0, audit["by_size"])
    @test sigma1_observe_trace.(population) == traces_before

    plan = sigma1_run_diversity_audit()
    @test !plan["execute"]
    @test plan["replicates"] == 10
    @test plan["seeds"] == collect(20260720:20260729)
    @test !plan["changes_selection_kernel"]

    withenv("ERIEC_SIGMA1_APPROVED" => nothing) do
        @test_throws ErrorException sigma1_run_diversity_audit(execute=true)
    end
    @test_throws ArgumentError check_sigma1_diversity_resolution(population[1:0])
end
