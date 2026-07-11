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

    verified_sys = ERIEState{Symbol,Symbol,Symbol,Symbol}(
        alpha_rel,
        sigma_rel,
        pi_rel,
        rho_rel,
        kappa,
        epsilon,
        Set([:c1]),
        :s,
        Set([:m1, :m2]),
        Set([:e1, :e2]),
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
        Set([:m1, :m2]),
        Set([:e1, :e2]),
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
