@testset "Richness" begin
    @test is_branch_point()
    @test !is_branch_point(Dict(:m0 => Set([:e0])), :m0)
    @test !is_branch_point(Dict(:m0 => Set{Symbol}()), :m0)

    @test check_hinge_branch_pump()
    @test !check_hinge_branch_pump(alpha_rel=Dict(:m0 => Set([:e0, :e2])))
    @test !check_hinge_branch_pump(
        sigma_rel=Dict(:e0 => Set{Symbol}(), :e1 => Set{Symbol}()),
    )
end
