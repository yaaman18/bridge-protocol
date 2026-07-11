@testset "reference models" begin
    @test check_reference_models()
    @test check_arbitrarily_large_nondegenerate_models()
    @test !check_arbitrarily_large_nondegenerate_models((1, 2))
    @test check_arbitrarily_large_ax_core_discrete_models()
    @test !check_arbitrarily_large_ax_core_discrete_models((0, 2))
    @test check_arbitrarily_large_three_layer_reference_models()
    @test !check_arbitrarily_large_three_layer_reference_models((1, 2))
    @test ERIEC._STABLE_REFERENCE_CONFIG[:s0].rank == :bottom
    @test ERIEC._STABLE_REFERENCE_CONFIG[:s2].rank == :top
    @test isempty(ERIEC._STABLE_REFERENCE_CONFIG[:s2].kappa)
    @test length(Set([false, true])) == 2
end
