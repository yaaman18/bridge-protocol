using Test
using Random
using ERIEC

@testset "Sigma1 individual adapter" begin
    plan = run_sigma1_experiment(replicate=0)
    @test plan.seed == 20260720
    @test plan.initial_population == 64

    population = sigma1_initial_population(0)
    repeated = sigma1_initial_population(0)
    @test length(population) == 64
    @test length(repeated) == 64
    @test all(
        left.alpha_edges == right.alpha_edges &&
            left.sigma_edges == right.sigma_edges &&
            left.quality_level == right.quality_level
        for (left, right) in zip(population, repeated)
    )

    candidates = sigma1_observe_candidate.(population)
    @test all(candidate -> candidate.dc_ok, candidates)
    @test all(candidate -> candidate.hinge_nonempty, candidates)
    @test all(candidate -> candidate.m4_safe, candidates)
    @test all(candidate -> isfinite(candidate.diversity), candidates)

    references = candidates[1:16]
    diversity_upper = 1.5 * maximum(candidate.diversity for candidate in references)
    reference_archive = qd_selection_step(
        references;
        diversity_upper,
        null_selection=true,
        rng=Xoshiro(plan.seed),
    ).archive
    small_archive = qd_selection_step(
        references[1:4];
        diversity_upper,
        null_selection=true,
        rng=Xoshiro(plan.seed),
    ).archive
    @test length(reference_archive.cells) >= 5
    @test length(small_archive.cells) >= 2
    @test Set(candidate.depth for candidate in references) == Set(1:4)

    finite_cap = maximum(candidate.diversity for candidate in candidates)
    @test finite_cap > 0
    @test all(candidate -> candidate.diversity <= finite_cap, candidates)
    @test all(candidate -> candidate.diversity == finite_cap, candidates[5:16])

    hashes = ERIEC._sigma1_trace_hashes(population)
    @test length(hashes) == 10
    @test all(item -> item.equal && item.left_hash == item.right_hash, hashes)

    mktempdir() do directory
        path = joinpath(directory, "audit.toml")
        ERIEC._sigma1_write_toml(path, Dict(
            "valid" => true,
            "pairs" => length(hashes),
            "plan" => ERIEC._sigma1_plan_payload(plan),
            "rules" => Dict("R2" => "pending_cross_replicate_statistics"),
        ))
        @test isfile(path)
        @test occursin("pairs = 10", read(path, String))
    end

    individual = population[1]
    alpha_before = deepcopy(individual.alpha_edges)
    sigma_before = deepcopy(individual.sigma_edges)
    trace_before = sigma1_observe_trace(individual)
    observed = sigma1_observe_candidate(individual)
    @test observed isa QDCandidate
    @test individual.alpha_edges == alpha_before
    @test individual.sigma_edges == sigma_before
    @test sigma1_observe_trace(individual) == trace_before

    mutant = sigma1_mutate(individual, Xoshiro(plan.seed))
    @test mutant !== individual
    @test individual.alpha_edges == alpha_before
    @test individual.sigma_edges == sigma_before

    rejected_individual = ERIEC._sigma1_build_individual(
        [Set(1:2), Set(1:2)],
        [Set{Int}(), Set{Int}()],
        1,
        2,
        99;
        diversity_cap=finite_cap,
    )
    rejected_candidate = sigma1_observe_candidate(rejected_individual)
    @test !rejected_candidate.dc_ok
    @test !rejected_candidate.hinge_nonempty
    @test isfinite(rejected_candidate.diversity)

    withenv("ERIEC_SIGMA1_APPROVED" => nothing) do
        error = try
            sigma1_run_all()
            nothing
        catch caught
            caught
        end
        @test error isa ErrorException
        @test occursin("ユーザー承認待ち", sprint(showerror, error))
    end
end
