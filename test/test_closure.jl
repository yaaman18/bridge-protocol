@testset "closure" begin
    pi_rel = m -> m == :m1 ? Set([:c1]) : Set([:c2])
    rho_rel = c -> c == :c1 ? Set([:m1]) : Set([:m2])

    @test pi_star(pi_rel, Set([:m1, :m2])) == Set([:c1, :c2])
    @test rho_star(rho_rel, Set([:c1])) == Set([:m1])
    @test Phi(pi_rel, rho_rel, Set([:c1])) == Set([:c1])

    all_C = Set([:c1, :c2])
    result = nu_phi(pi_rel, rho_rel, all_C)
    @test result.converged
    @test check_nu_phi_fixedpoint(pi_rel, rho_rel, result)
    @test check_final_coalgebra(pi_rel, rho_rel, result, all_C)

    delayed_pi_rel = m -> m == :m1 ? Set([:c1]) :
                         m == :m2 ? Set([:c2]) :
                         Set{Symbol}()
    delayed_rho_rel = c -> c == :c1 ? Set([:m1]) :
                          c == :c2 ? Set([:m3]) :
                          Set([:m2])
    delayed = nu_phi(delayed_pi_rel, delayed_rho_rel, Set([:c1, :c2, :c3]))
    @test delayed.converged
    @test delayed.iterations == 3
    @test delayed.value == Set([:c1])
    @test check_nu_phi_fixedpoint(delayed_pi_rel, delayed_rho_rel, delayed)

    budget_limited = nu_phi(delayed_pi_rel, delayed_rho_rel, Set([:c1, :c2, :c3]); max_iter=1)
    @test !budget_limited.converged
    @test budget_limited.iterations == 1
    @test budget_limited.value == Set([:c1, :c2])
    @test !check_nu_phi_fixedpoint(delayed_pi_rel, delayed_rho_rel, budget_limited)
    @test !check_final_coalgebra(
        delayed_pi_rel,
        delayed_rho_rel,
        budget_limited,
        Set([:c1, :c2, :c3]),
    )

    X = Set([:c1])
    Y = Set([:c1, :c2])
    @test X ⊆ Y
    @test Phi(pi_rel, rho_rel, X) ⊆ Phi(pi_rel, rho_rel, Y)
end
