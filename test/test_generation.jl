using Test
using ERIEC

@testset "generation boundary audits" begin
    @test check_dc_viable_translation()
    @test !check_dc_viable_translation(inverse_translation=true)

    @test check_proliferation_morphism()
    @test !check_proliferation_morphism(branch_transport=false)
    @test !check_proliferation_morphism(child_rank_le_wstar=false)
    @test !check_proliferation_morphism(phi_rich_lax=false)
    @test !check_proliferation_morphism(inverse_translation=true)

    @test check_lineage_stays_open()
    @test !check_lineage_stays_open(phi_rich_fixed=false)
    @test !check_lineage_stays_open(asserts_eventual_periodicity=true)

    @test check_richness_inherits_generational()
    @test !check_richness_inherits_generational(child_pump=false)
    @test !check_richness_inherits_generational(phi_rich_lax=false)
    richness_witness = check_richness_inherits_generational(2, 3)
    @test richness_witness.inequality_holds
    @test richness_witness.field_valid
    @test richness_witness.contract_holds
    @test !check_richness_inherits_generational(3, 2).contract_holds
    @test !check_richness_inherits_generational(2, 3; phi_rich_lax=false).contract_holds

    @test check_rich_lineage_cofinal(5, 4)
    @test !check_rich_lineage_cofinal(5, 6)
    @test !check_rich_lineage_cofinal(5, 4; semantic_invariant=false)
    @test !check_rich_lineage_cofinal(5, 4; step_certificates=[true, true])
    @test !check_rich_lineage_cofinal(5, 4; scores=[1, 2, 3, 4, 5, 5])
    @test_throws ArgumentError check_rich_lineage_cofinal(-1, 0)
    @test_throws ArgumentError check_rich_lineage_cofinal(1, -1)

    @test check_branched_rich_lineage_cofinal(5, 4)
    @test !check_branched_rich_lineage_cofinal(5, 4;
        branch_witnesses=[true, true, false, true, true, true])
    @test !check_branched_rich_lineage_cofinal(5, 4;
        branch_transports=[true, true, false, true, true])
    @test !check_branched_rich_lineage_cofinal(5, 6)
    @test_throws ArgumentError check_branched_rich_lineage_cofinal(-1, 0)
end
