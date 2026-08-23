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

    # Literal oracle for the complete Bool^4 input table. Expected values are
    # not derived from either classifier implementation.
    classification_oracle = [
        (false, false, false, false, :nonconscious),
        (false, false, false, true, :nonconscious),
        (false, false, true, false, :nonconscious),
        (false, false, true, true, :nonconscious),
        (false, true, false, false, :nonconscious),
        (false, true, false, true, :nonconscious),
        (false, true, true, false, :nonconscious),
        (false, true, true, true, :nonconscious),
        (true, false, false, false, :nonconscious),
        (true, false, false, true, :blindsight_analog),
        (true, false, true, false, :nonconscious),
        (true, false, true, true, :blindsight_analog),
        (true, true, false, false, :nonconscious),
        (true, true, false, true, :blindsight_analog),
        (true, true, true, false, :nonconscious),
        (true, true, true, true, :conscious),
    ]
    for (fm1, fm2, fm3, fm4, expected) in classification_oracle
        markers = FMMarkers(fm1, fm2, fm3, fm4)
        @test classify_action_markers(markers) === expected
        @test check_marker_classification(markers, expected)
        mutated = expected === :nonconscious ? :conscious : :nonconscious
        @test !check_marker_classification(markers, mutated)
    end
    @test !check_marker_classification(conscious, :unknown_functional_class)
end
