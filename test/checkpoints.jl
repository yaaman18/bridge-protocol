@testset "checkpoints" begin
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

    @test check_K2(sys)
    @test check_K2_strict(sys)

    vulnerable_sys = ERIEState{Symbol,Symbol,Symbol,Symbol}(
        alpha_rel,
        e -> e == :e1 ? Set([:m1, :m2]) : Set(),
        pi_rel,
        rho_rel,
        kappa,
        epsilon,
        Set([:c1]),
        :s,
    )
    @test check_K2(vulnerable_sys)
    @test_logs (:warn, r"K2 strict check failed") begin
        @test !check_K2_strict(vulnerable_sys)
    end
    @test check_K3(alpha_rel, Set([:m1, :m2]), powerset(Set([:e1, :e2])))
    @test check_K1()
    @test check_K1_endogenous_response(EndogenousBodyResponse(identity, identity))
    @test !check_K1_endogenous_response(BodyResponse(identity))
    @test check_K1_structural(EndogenousBodyResponse(identity, identity))
    @test !check_K1_structural(BodyResponse(identity))
    open_diagram = SetPointDiagram([:seek, :probe], ==)
    closed_diagram = SetPointDiagram(
        [:seek, :target],
        (source, candidate) -> source == candidate || candidate == :target,
    )
    @test check_K1_structural(
        EndogenousBodyResponse(identity, identity);
        setpoint_diagram=open_diagram,
    )
    @test !check_K1_structural(
        EndogenousBodyResponse(identity, identity);
        setpoint_diagram=closed_diagram,
    )

    mktempdir() do dir
        good = joinpath(dir, "good.jl")
        bad = joinpath(dir, "bad.jl")
        write(good, "target = 1.0\n")
        write(bad, "external_setpoint = :bad\n")

        @test isempty(forbidden_external_setpoint_terms([good]))
        matches = forbidden_external_setpoint_terms([bad])
        @test length(matches) == 1
        @test matches[1].term == "external_setpoint"
        @test !check_K1(src_dir=dir)
    end
end
