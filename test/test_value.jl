@testset "value" begin
    @testset "viabilityContribution_ext" begin
        nu_phi = Set([:c1, :c2])
        contribution1 = e -> e == :e1 ? Set([:c2, :c3]) : Set([:c4])
        contribution2 = e -> e == :e1 ? Set([:c2, :c3]) : Set([:other])

        @test viability_contribution(nu_phi, contribution1, :e1) ==
              viability_contribution(nu_phi, contribution2, :e1)
    end

    @testset "has_structural_weight" begin
        nu_phi = Set([:c1, :c2])
        contribution = _ -> Set([:c2, :c3])

        @test viability_contribution(nu_phi, contribution, :e1) > 0
        @test has_structural_weight(nu_phi, contribution, :e1)
    end

    @testset "viability_weight_ratio" begin
        nu_phi = Set([:c1, :c2, :c3, :c4])
        contribution = _ -> Set([:c2, :c4, :outside])

        @test cardinality_measure().mu(nu_phi) == 4
        @test viability_weight_ratio(nu_phi, contribution, :e1) == 0.5
        @test viability_weight_ratio(nu_phi, _ -> Set([:outside]), :e1) == 0.0
        @test viability_weight_ratio(nu_phi, _ -> copy(nu_phi), :e1) == 1.0

        weights = Dict(:c1 => 1.0, :c2 => 2.0, :c3 => 3.0, :c4 => 4.0)
        weighted = Measure(items -> sum(get(weights, item, 0.0) for item in items))
        @test viability_weight_ratio(nu_phi, contribution, :e1; measure=weighted) == 0.6

        @test_throws ArgumentError viability_weight_ratio(Set(), contribution, :e1)
        @test viability_contribution(nu_phi, contribution, :e1) == 2
    end

    @testset "Countermodel" begin
        model = value_countermodel()

        @test has_structural_weight(model.nu_phi, model.contribution, ())
        @test !model.mattering(())

        stable_model = stable_value_countermodel()
        @test stable_model isa StableValueCountermodel
        @test check_value_countermodel(stable_model)
        @test isempty(stable_model.relation(true, ()))
        @test stable_model.relation(false, ()) == Set([()])
        @test !stable_model.external_predicate(())
    end

    @testset "no_general_structural_to_mattering" begin
        model = value_countermodel()

        @test has_structural_weight(model.nu_phi, model.contribution, ())
        @test !model.mattering(())
    end

    @testset "mattering_of_bridge" begin
        model = value_countermodel()
        bridge = MatteringBridge(_ -> true)

        @test mattering_of_bridge(bridge, model.nu_phi, model.contribution, ())
    end


    @testset "endogenous normalized value" begin
        nu_phi = Set([:c1, :c2])
        contribution = _ -> Set([:c2, :outside])
        @test check_value_endogenous(nu_phi, contribution, :e)
        @test !check_value_endogenous(Set(), contribution, :e)

        all_C = Set([:c1, :c2])
        sigma_rel = _ -> Set([:m1])
        pi_rel = _ -> Set([:c1])
        rho_rel = c -> c == :c1 ? Set([:m1]) : Set()
        @test relational_normalized_value(
            all_C, sigma_rel, pi_rel, rho_rel, :e,
        ) == 1.0
        @test check_value_endogenous(
            all_C,
            sigma_rel,
            pi_rel,
            rho_rel,
            sigma_rel,
            pi_rel,
            rho_rel,
            :e,
        )
        sigma_copy = _ -> Set([:m1])
        @test !check_value_endogenous(
            all_C,
            sigma_rel,
            pi_rel,
            rho_rel,
            sigma_copy,
            pi_rel,
            rho_rel,
            :e,
        )
    end
end
