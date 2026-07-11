@testset "finite relation linearization" begin
    all_M = [:m1, :m2]
    all_E = [:e1, :e2, :e3]
    alpha_rel = m -> m == :m1 ? Set([:e1, :e3]) : Set([:e2])
    sigma_rel = e -> e == :e1 || e == :e3 ? Set([:m1]) : Set([:m2])

    alpha_matrix = relation_incidence_matrix(alpha_rel, all_M, all_E)
    sigma_matrix = relation_incidence_matrix(sigma_rel, all_E, all_M)
    @test size(alpha_matrix) == (3, 2)
    @test alpha_matrix == [1.0 0.0; 0.0 1.0; 1.0 0.0]
    @test sigma_matrix == transpose(alpha_matrix)
    @test check_converse_adjoint(alpha_rel, sigma_rel, all_M, all_E)

    sigma = x -> alpha_matrix * x
    @test check_relation_sensitivity_bridge(
        alpha_rel,
        all_M,
        all_E,
        sigma,
        zeros(length(all_M)),
    )

    mismatched_sigma = x -> 2.0 .* (alpha_matrix * x)
    @test !check_relation_sensitivity_bridge(
        alpha_rel,
        all_M,
        all_E,
        mismatched_sigma,
        zeros(length(all_M)),
    )

    invalid_sigma = _ -> Set([:m1, :m2])
    @test !check_converse_adjoint(alpha_rel, invalid_sigma, all_M, all_E)

    all_M_prime = [:u2, :u1]
    all_E_prime = [:v3, :v1, :v2]
    map_M = m -> m == :m1 ? :u1 : :u2
    map_E = e -> e == :e1 ? :v1 : e == :e2 ? :v2 : :v3
    alpha_rel_prime = u -> u == :u1 ? Set([:v1, :v3]) : Set([:v2])
    @test check_relation_linearization_naturality(
        alpha_rel,
        alpha_rel_prime,
        all_M,
        all_E,
        all_M_prime,
        all_E_prime,
        map_M,
        map_E,
    )
    @test !check_relation_linearization_naturality(
        alpha_rel,
        _ -> Set([:v1]),
        all_M,
        all_E,
        all_M_prime,
        all_E_prime,
        map_M,
        map_E,
    )

    lax_rel_prime = u -> u == :u1 ? Set([:v1, :v2, :v3]) : Set([:v2])
    @test check_relation_hom_lax_naturality(
        alpha_rel,
        lax_rel_prime,
        all_M,
        all_E,
        map_M,
        map_E,
    )
    counterexample = strict_relation_hom_naturality_counterexample()
    @test counterexample.lax
    @test !counterexample.strict
    @test counterexample.source == zeros(1, 1)
    @test counterexample.target == ones(1, 1)
end
