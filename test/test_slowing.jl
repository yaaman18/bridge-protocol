@testset "critical slowing" begin
    loop1 = [
        0.5 0.0
        0.0 0.2
    ]
    loop2 = [
        0.9 0.0
        0.0 0.2
    ]
    loop3 = [
        0.99 0.0
        0.0 0.2
    ]

    @test dominant_world_eigenvalue(loop1) ≈ 0.5
    @test world_chi(loop1) ≈ 0.5
    @test world_chi(loop3) ≈ 0.01
    @test critical_slowing_score(loop3) > critical_slowing_score(loop2)

    series = critical_slowing_series([loop1, loop2, loop3])
    @test series.eigenvalues ≈ [0.5, 0.9, 0.99]
    @test series.scores[3] > series.scores[2] > series.scores[1]
    @test series.approaching
    assessment = critical_slowing_assessment([loop1, loop2, loop3])
    @test assessment.warning
    @test assessment.threshold ≈ 0.95
    @test assessment.lead_time == 5
    @test_throws DimensionMismatch dominant_world_eigenvalue([1.0 0.0])
end
