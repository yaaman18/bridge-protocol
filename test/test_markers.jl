@testset "functional markers" begin
    tensor = [
        1.0 0.0
        0.5 2.0
        0.0 0.0
    ]
    world = actuated_world([
        1.0 0.0
        0.0 0.5
    ]; target=1.0, tol=1e-10)

    @test fm1_global_participation(true, false)
    @test !fm1_global_participation(true, true)
    @test fm2_sensorimotor_integration(tensor, 1; min_channels=2)
    @test !fm2_sensorimotor_integration(tensor, 2; min_channels=2)
    @test fm3_self_monitoring([0.0, 0.1])
    @test !fm3_self_monitoring([0.0, 0.0])
    @test fm4_world_participation(world, 1)
    @test !fm4_world_participation(world, 2)

    conscious = FMMarkers(true, true, true, true)
    blindsight = FMMarkers(true, false, true, true)
    absent = FMMarkers(false, true, true, true)
    @test classify_action_markers(conscious) == :conscious
    @test classify_action_markers(blindsight) == :blindsight_analog
    @test classify_action_markers(absent) == :nonconscious
end
