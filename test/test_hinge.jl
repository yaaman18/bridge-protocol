@testset "hinge" begin
    alpha_rel = m -> m == :m1 ? Set([:e1]) : Set([:e2])
    sigma_rel = e -> e == :e1 ? Set([:m1]) : Set([:m2])
    rho_rel = c -> c == :c1 ? Set([:m1]) : Set([:m2])
    kappa = s -> Set([:c1])
    epsilon = s -> Set([:e1])

    @test T_prime(alpha_rel, sigma_rel, Set([:e1])) == Set([:e1])
    @test Act(rho_rel, sigma_rel, kappa, epsilon, :s) == Set([:m1])
    @test check_hinge(rho_rel, sigma_rel, kappa, epsilon, :s)
    @test isempty(Act(rho_rel, sigma_rel, kappa, _ -> Set(), :s))

    integrity = hinge_integrity(rho_rel, sigma_rel, kappa, epsilon, :s)
    @test integrity.accepted
    @test integrity.act == Set([:m1])
    @test isempty(integrity.sensory_only)
    @test isempty(integrity.self_only)

    sensory_only_sigma = e -> e == :e1 ? Set([:m1, :m2]) : Set()
    vulnerable = hinge_integrity(
        rho_rel,
        sensory_only_sigma,
        kappa,
        epsilon,
        :s,
    )
    @test vulnerable.act == Set([:m1])
    @test vulnerable.sensory_only == Set([:m2])
    @test !vulnerable.accepted
end
