@testset "dc" begin
    alpha_rel = m -> m == :m1 ? Set([:e1]) : Set([:e2])
    sigma_rel = e -> e == :e1 ? Set([:m1]) : Set([:m2])
    pi_rel = m -> m == :m1 ? Set([:c1]) : Set([:c2])
    rho_rel = c -> c == :c1 ? Set([:m1]) : Set([:m2])
    kappa = s -> Set([:c1])
    epsilon = s -> Set([:e1])
    sys = ERIEState{Symbol,Symbol,Symbol,Symbol}(
        alpha_rel,
        sigma_rel,
        pi_rel,
        rho_rel,
        kappa,
        epsilon,
        Set([:c1]),
        :s,
    )

    result = check_DC(sys)
    @test result.hSelf
    @test result.hSMC
    @test result.hAct
    @test result.hBound
    @test is_DC(result)
    @test sys.structure.hGC === nothing
    all_M = Set([:m1, :m2])
    all_E = Set([:e1, :e2])
    all_C = Set([:c1, :c2])
    @test check_DC(sys, all_M, all_E, all_C)

    no_self = ERIEState{Symbol,Symbol,Symbol,Symbol}(
        alpha_rel, sigma_rel, _ -> Set{Symbol}(), rho_rel,
        kappa, epsilon, Set([:c1]), :s,
    )
    @test !check_DC(no_self, all_M, all_E, all_C)
    no_smc = ERIEState{Symbol,Symbol,Symbol,Symbol}(
        _ -> Set{Symbol}(), sigma_rel, pi_rel, rho_rel,
        kappa, epsilon, Set([:c1]), :s,
    )
    @test !check_DC(no_smc, all_M, all_E, all_C)
    no_act = ERIEState{Symbol,Symbol,Symbol,Symbol}(
        alpha_rel, sigma_rel, pi_rel, _ -> Set{Symbol}(),
        kappa, epsilon, Set([:c1]), :s,
    )
    @test !check_DC(no_act, all_M, all_E, all_C)
    no_bound = ERIEState{Symbol,Symbol,Symbol,Symbol}(
        alpha_rel, sigma_rel, pi_rel, rho_rel,
        kappa, epsilon, Set{Symbol}(), :s,
    )
    @test !check_DC(no_bound, all_M, all_E, all_C)

    verified_sys = ERIEState{Symbol,Symbol,Symbol,Symbol}(
        alpha_rel,
        sigma_rel,
        pi_rel,
        rho_rel,
        kappa,
        epsilon,
        Set([:c1]),
        :s,
        all_M,
        all_E,
    )
    @test verified_sys.structure.hGC === true

    invalid_sigma_rel = _ -> Set([:m1, :m2])
    @test_throws ArgumentError ERIEState{Symbol,Symbol,Symbol,Symbol}(
        alpha_rel,
        invalid_sigma_rel,
        pi_rel,
        rho_rel,
        kappa,
        epsilon,
        Set([:c1]),
        :s,
        all_M,
        all_E,
    )
end


@testset "critical certification bound" begin
    collapsing = (rank, configuration) -> rank <= 1 ? copy(configuration) : Set{Symbol}()
    persistent = (_, configuration) -> copy(configuration)
    configuration = Set([:c1])

    @test check_critical_bound(collapsing, 1, 2, <, configuration)
    @test check_critical_bound(persistent, 1, 1, <, configuration)
    @test !check_critical_bound(persistent, 1, 2, <, configuration)
end
