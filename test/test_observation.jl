@testset "observation summary" begin
    sensory = [1.0, 2.0, 3.0]
    world = actuated_world([
        1.0 0.0
        0.0 0.5
    ]; target=1.0, tol=1e-10)
    dc = DCResult(true, true, true, true, Set([:act]))

    summary = summarize_observation(sensory, world, dc)
    @test summary isa NamedTuple
    @test summary.sensory_summary.min <= summary.sensory_summary.mean <= summary.sensory_summary.max
    @test summary.sensory_summary.length == length(sensory)
    @test summary.world_summary.nontrivial isa Bool
    @test summary.world_summary.eigenvalues isa Vector{Float64}
    @test summary.dc_summary.is_dc isa Bool
    @test summary.dc_summary.is_dc

    @test_throws ArgumentError summarize_observation(Float64[], world, dc)
end
