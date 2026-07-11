using Test
using ERIEC

@testset "generation boundary audits" begin
    @test check_dc_viable_translation()
    @test !check_dc_viable_translation(inverse_translation=true)

    @test check_proliferation_morphism()
    @test !check_proliferation_morphism(branch_transport=false)
    @test !check_proliferation_morphism(inverse_translation=true)

    @test check_lineage_stays_open()
    @test !check_lineage_stays_open(asserts_eventual_periodicity=true)

    @test check_richness_inherits_generational()
    @test !check_richness_inherits_generational(child_pump=false)
end
