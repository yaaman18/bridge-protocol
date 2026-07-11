using ForwardDiff

@testset "weighted sensitivity" begin
    tensor = [
        1.0 2.0
        3.0 4.0
    ]
    weights = [2.0, 0.5]

    @test weighted_sensitivity(tensor, weights) == [
        2.0 1.0
        6.0 2.0
    ]
    @test weighted_sensitivity(tensor, zeros(2)) == zeros(2, 2)
    @test_throws DimensionMismatch weighted_sensitivity(tensor, [1.0])

    dual_weights = ForwardDiff.Dual.(weights, (1.0, 0.0))
    dual_weighted = weighted_sensitivity(tensor, dual_weights)
    @test size(dual_weighted) == size(tensor)
    @test dual_weighted[1, 1] isa ForwardDiff.Dual

    nu_phi = Set([:c1, :c2])
    contribution = e -> e == :e1 ? Set([:c1]) : Set([:c2, :c3])
    @test viability_weights(nu_phi, contribution, [:e1, :e2]) == [1, 1]
end
