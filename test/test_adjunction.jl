@testset "adjunction" begin
    all_M = Set([:m1, :m2])
    all_E = Set([:e1, :e2])
    alpha_rel = m -> m == :m1 ? Set([:e1]) : Set([:e1, :e2])
    subsets_E = powerset(all_E)

    @test alpha_star(alpha_rel, Set([:m1])) == Set([:e1])
    @test sigma_star_induced(alpha_rel, all_M, Set([:e1])) == Set([:m1])
    @test check_K3(alpha_rel, all_M, subsets_E)

    gc_alpha_rel = m -> m == :m1 ? Set([:e1]) : Set([:e2])
    sigma_rel = e -> e == :e1 ? Set([:m1]) : Set([:m2])
    @test sigma_star(sigma_rel, Set([:e1, :e2])) == all_M
    @test check_galois_conn(gc_alpha_rel, sigma_rel, all_M, subsets_E)
    @test check_relational_rigidity(gc_alpha_rel, sigma_rel, all_M, all_E)

    invalid_sigma_rel = _ -> all_M
    @test !check_galois_conn(gc_alpha_rel, invalid_sigma_rel, all_M, subsets_E)
    @test !check_relational_rigidity(alpha_rel, sigma_rel, all_M, all_E)

    structure = ERIEStructure{Symbol,Symbol,Symbol}(
        gc_alpha_rel,
        sigma_rel,
        _ -> Set{Symbol}(),
        _ -> Set{Symbol}(),
        all_M,
        all_E,
    )
    @test check_erie_structure(structure)
    @test check_erie_structure(structure; all_M=all_M, all_E=all_E)
    @test !check_erie_structure(
        ERIEStructure{Symbol,Symbol,Symbol}(
            gc_alpha_rel,
            invalid_sigma_rel,
            _ -> Set{Symbol}(),
            _ -> Set{Symbol}(),
            false,
        ),
    )
end
