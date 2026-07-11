@testset "bridge functor obstructions" begin
    witness = alpha_only_hinge_counterexample()
    @test witness.same_alpha
    @test witness.full
    @test !witness.empty
    @test witness.refutes_alpha_only

    gram_witness = raw_gram_bridge_counterexample()
    @test gram_witness.hinge_nonempty
    @test gram_witness.gram == fill(2.0, 1, 1)
    @test gram_witness.eigenvalues == [2.0]
    @test !gram_witness.fixed_nontrivial

    rho_full = _ -> Set([:m])
    rho_empty = _ -> Set{Symbol}()
    sigma_rel = _ -> Set([:m])
    kappa = _ -> Set([:c])
    epsilon = _ -> Set([:e])

    classified_full = check_hinge_classifying_loop(
        rho_full, sigma_rel, kappa, epsilon, :s,
    )
    @test classified_full.hinge_nonempty
    @test classified_full.fixed_nontrivial
    @test classified_full.equivalent
    @test classified_full.loop == ones(1, 1)

    classified_empty = check_hinge_classifying_loop(
        rho_empty, sigma_rel, kappa, epsilon, :s,
    )
    @test !classified_empty.hinge_nonempty
    @test !classified_empty.fixed_nontrivial
    @test classified_empty.equivalent
    @test classified_empty.loop == zeros(1, 1)

    empty_to_full = check_hinge_classifying_loop_lax(
        rho_empty, sigma_rel, kappa, epsilon, :s,
        rho_full, sigma_rel, kappa, epsilon, :s,
    )
    @test empty_to_full.forward_preserved
    @test empty_to_full.lax_norm
    @test empty_to_full.law_exact

    full_to_full = check_hinge_classifying_loop_lax(
        rho_full, sigma_rel, kappa, epsilon, :s,
        rho_full, sigma_rel, kappa, epsilon, :s,
    )
    @test full_to_full.forward_preserved
    @test full_to_full.lax_norm
    @test full_to_full.law_exact

    full_to_empty = check_hinge_classifying_loop_lax(
        rho_full, sigma_rel, kappa, epsilon, :s,
        rho_empty, sigma_rel, kappa, epsilon, :s,
    )
    @test !full_to_empty.forward_preserved
    @test !full_to_empty.lax_norm
    @test full_to_empty.law_exact

    for source_live in (false, true), middle_live in (false, true),
        target_live in (false, true)
        laws = check_hinge_classifier_functor_laws(
            source_live, middle_live, target_live,
        )
        @test laws.identity_law
        @test laws.composition_law
        @test laws.functor_laws
    end

    for source_live in (false, true), target_live in (false, true)
        strict = check_strict_hinge_classifier_intertwining(
            source_live, target_live,
        )
        @test strict.arrow_valid == (source_live == target_live)
        @test strict.loops_equal == strict.arrow_valid
        @test strict.identity_intertwines == strict.arrow_valid
        @test strict.law_exact
    end


    for source_live in (false, true), middle_live in (false, true),
        target_live in (false, true)
        hilbert_functor = check_hinge_hilbert_functor(
            source_live, middle_live, target_live,
        )
        @test hilbert_functor.identity_law
        @test hilbert_functor.composition_law
        @test hilbert_functor.functor_laws
    end


    structural = structural_hinge_isomorphism_witness()
    @test structural.action_bijection
    @test structural.mapped_act == Set([:n2])
    @test structural.hinge_preserved
    @test structural.nonempty_equivalent
    @test structural.loops_equal
end
