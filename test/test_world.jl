using LinearAlgebra

@testset "world" begin
    @testset "loop operator and eigenspace" begin
        tensor = [
            1.0 0.0
            0.0 0.5
        ]

        loop = world_loop_operator(tensor)
        @test loop == transpose(tensor) * tensor

        world = actuated_world(tensor; target=1.0, tol=1e-10)
        @test world.loop == loop
        @test world_nontrivial(world)
        @test count(world.selected) == 1
        @test world_admissible(loop, [1.0, 0.0], 1e-10)
        @test !world_admissible(loop, [0.0, 1.0], 0.1)
        @test_throws ArgumentError world_admissible(loop, [1.0, 0.0], -1.0)
        @test world_projection(world) ≈ [
            1.0 0.0
            0.0 0.0
        ]
    end

    @testset "no invariant world near target" begin
        tensor = [
            0.25 0.0
            0.0 0.5
        ]

        world = actuated_world(tensor; target=1.0, tol=1e-10)
        @test !world_nontrivial(world)
        @test world_projection(world) == zeros(2, 2)
    end

    @testset "sigma-derived world and Umwelt relativity" begin
        sigma1 = a -> [
            a[1],
            0.5a[2],
        ]
        sigma2 = a -> [
            0.5a[1],
            a[2],
        ]
        a = [0.0, 0.0]

        world1 = actuated_world(sigma1, a; target=1.0, tol=1e-10)
        world2 = actuated_world(sigma2, a; target=1.0, tol=1e-10)

        @test world_nontrivial(world1)
        @test world_nontrivial(world2)
        @test world_projection(world1) ≈ [
            1.0 0.0
            0.0 0.0
        ]
        @test world_projection(world2) ≈ [
            0.0 0.0
            0.0 1.0
        ]
        @test check_umwelt_relative(sigma1, a, sigma2, a; eig_tol=1e-10)
    end

    @testset "direct SVD and truncation" begin
        tensor = [1.0 0.0 0.0; 0.0 0.8 0.0; 0.0 0.0 0.4]
        dense = actuated_world(tensor; method=:dense, target=1.0, tol=1e-10)
        direct = actuated_world(tensor; method=:svd, rank=3, target=1.0, tol=1e-10)

        @test !dense.truncated
        @test !direct.truncated
        @test direct.loop isa TensorGramOperator
        @test issorted(direct.eigenvalues)
        @test norm(world_projection(dense) - world_projection(direct)) <= 1e-8
        @test direct.loop * [1.0, 2.0, 3.0] ≈
              world_loop_operator(tensor) * [1.0, 2.0, 3.0]

        truncated = actuated_world(tensor; method=:svd, rank=2)
        @test truncated.truncated
        @test length(truncated.eigenvalues) == 2
        high_dimensional = actuated_world(ones(4, WLD_DENSE_THRESHOLD + 1))
        @test high_dimensional.loop isa TensorGramOperator
        @test !high_dimensional.truncated
        @test WLD_SVD_POWER_ITERATIONS == 2

        singularvalues = vcat([1.0, 0.8, 0.6], zeros(WLD_DENSE_THRESHOLD - 2))
        large_tensor = Matrix(Diagonal(singularvalues))
        large_dense = actuated_world(
            large_tensor;
            method=:dense,
            target=1.0,
            tol=1e-10,
        )
        large_svd = actuated_world(
            large_tensor;
            method=:svd,
            rank=3,
            target=1.0,
            tol=1e-10,
            oversample=2,
            power_iterations=2,
            seed=17,
        )
        large_svd_repeat = actuated_world(
            large_tensor;
            method=:svd,
            rank=3,
            target=1.0,
            tol=1e-10,
            oversample=2,
            power_iterations=2,
            seed=17,
        )
        @test norm(world_projection(large_dense) - world_projection(large_svd)) <= 1e-8
        @test large_svd.eigenvalues == large_svd_repeat.eigenvalues
        @test world_projection(large_svd) == world_projection(large_svd_repeat)
        @test_throws ArgumentError actuated_world(tensor; method=:unknown)
        @test_throws ArgumentError actuated_world(tensor; method=:svd, rank=4)
        @test_throws ArgumentError actuated_world(
            tensor;
            method=:svd,
            rank=2,
            power_iterations=-1,
        )
    end

    @testset "Wld reach probe" begin
        world = actuated_world([1.0 0.0; 0.0 0.5]; tol=1e-10)
        reached = wld_reach_probe(world, [1.0, 1.0])
        @test reached.status == :reached
        @test reached.final_overlap >= 1 - 1e-3
        @test reached.iterations == length(reached.overlap_history)
        @test reached.target_is_dominant
        @test reached.diagnostic == :target_attractor

        diverged = wld_reach_probe(world, [0.0, 1.0]; max_iters=10)
        @test diverged.status == :diverged
        @test diverged.final_overlap <= 1e-3

        non_dominant = actuated_world(
            [1.0 0.0; 0.0 2.0];
            target=1.0,
            tol=1e-10,
        )
        non_dominant_probe = wld_reach_probe(
            non_dominant,
            [1.0, 1.0];
            max_iters=100,
        )
        @test !non_dominant_probe.target_is_dominant
        @test non_dominant_probe.status == :diverged
        @test non_dominant_probe.diagnostic == :target_not_dominant

        incomplete = wld_reach_probe(
            world,
            [1.0, 1.0];
            max_iters=1,
            conv_tol=0.0,
            reach_tol=0.0,
        )
        @test incomplete.status == :non_converged
        @test_throws DimensionMismatch wld_reach_probe(world, [1.0])
    end

    @testset "spectral world band" begin
        tensor = [1.0 0.0; 0.0 sqrt(1.2)]
        narrow = world_band(tensor; eta=0.05)
        wide = world_band(tensor; eta=0.25)
        @test size(narrow.basis, 2) == 1
        @test size(wide.basis, 2) == 2
        @test_throws ArgumentError world_band(tensor; eta=-0.1)
    end
end
