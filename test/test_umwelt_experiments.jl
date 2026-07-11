@testset "umwelt comparison and series" begin
    action = [0.0, 0.0]
    dc = DCResult(true, true, true, true, Set([:act]))
    adapter1 = toy_recurrent_adapter(
        ToyRecurrentSystem(zeros(2, 2), [
            1.0 0.0
            0.0 1.0
        ]),
        [0.0, 0.0],
    )
    adapter2 = toy_recurrent_adapter(
        ToyRecurrentSystem(zeros(2, 2), [
            0.5 0.0
            0.0 1.0
        ]),
        [0.0, 0.0],
    )

    comparison = compare_umwelt(adapter1, adapter2, action; eig_tol=1e-10)
    @test comparison.projection_distance > 0
    @test comparison.changed

    direction = [1.0, -1.0] / sqrt(2)
    series = run_system_series(
        adapter1,
        [action, action],
        dc;
        direction=direction,
        eig_tol=1e-10,
        fixed_tol=1e-10,
    )
    @test length(series.results) == 2
    @test length(series.slowing.eigenvalues) == 2
end
