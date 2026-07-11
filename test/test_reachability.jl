@testset "reachability" begin
    world = actuated_world([
        1.0 0.0
        0.0 0.5
    ]; target=1.0, tol=1e-10)

    reachable = reachable_world_projection(world, [1.0, 0.0]; tol=1e-10)
    @test reachable.reachable
    @test reachable.overlap_norm ≈ 1.0

    unreachable = reachable_world_projection(world, [0.0, 1.0]; tol=1e-10)
    @test !unreachable.reachable
    @test unreachable.overlap_norm ≈ 0.0

    @test check_wld_reachable(world, [1.0, 0.0]; tol=1e-10)
    @test !check_wld_reachable(world, [0.0, 1.0]; tol=1e-10)
    @test_throws DimensionMismatch reachable_world_projection(world, [1.0, 0.0, 0.0])
end
