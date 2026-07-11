using LinearAlgebra

@testset "sensitivity" begin
    sigma = a -> [sin(a[1]), a[1] * a[2]]
    a = [0.3, 0.7]

    tensor = sensitivity_tensor(sigma, a)
    expected = [
        cos(a[1]) 0.0
        a[2] a[1]
    ]

    @test size(tensor) == (2, 2)
    @test tensor ≈ expected
    @test sensitivity_tensor_adjoint(sigma, a) == transpose(tensor)
    @test check_dual_symmetry(sigma, a, [1.2, -0.4], [0.5, 2.0])
    @test check_adjoint_unit_counterexample(zeros(2, 2))
    @test !check_adjoint_unit_counterexample(Matrix{Float64}(I, 2, 2))
end
