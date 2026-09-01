using Test
using ERIEC

@testset "loss-aware branch novelty" begin
    observation(fibres; environments=[:e0, :e1, :e2]) =
        FiniteBranchObservation(
            collect(keys(fibres)),
            environments,
            motor -> Set(fibres[motor]),
            environment -> Set(
                motor for (motor, fibre) in fibres if environment in fibre),
        )
    identity = FiniteEnvironmentIdentity((_, environment) -> environment)

    first = observation(Dict(:m0 => [:e0, :e1]))
    lost = observation(Dict(:m0 => [:e0]))
    reappeared = observation(Dict(:m0 => [:e0, :e1]))
    expanded = observation(Dict(:m0 => [:e0, :e1, :e2]))
    observations = [first, lost, reappeared, expanded]

    @test all(check_branch_observation, observations)
    @test check_environment_identity(observations, identity)
    score = finite_branch_score(observations, identity)
    @test score.scores == [1, 1, 1, 2]
    @test score.novel_counts == [1, 0, 0, 1]
    @test score.lost_counts == [0, 1, 0, 1]
    @test check_finite_branch_score(
        observations, identity;
        scores=[1, 1, 1, 2], novel_counts=[1, 0, 0, 1], lost_counts=[0, 1, 0, 1],
    )
    @test !check_finite_branch_score(
        observations, identity;
        scores=[1, 1, 1, 3], novel_counts=[1, 0, 0, 1], lost_counts=[0, 1, 0, 1],
    )
    @test check_branch_fresh_prefix(score; cutoff=4)
    @test check_branch_fresh_prefix(score; cutoff=2)
    @test check_branch_novelty_route(observations, identity; cutoff=4)
    @test check_shared_environment_carrier(observations)
    @test check_canonical_branch_novelty_route(observations; cutoff=4)

    # Branch-free observations never create a positive score.
    branch_free = [observation(Dict(:m0 => [:e0]))]
    branch_free_score = finite_branch_score(branch_free, identity)
    @test branch_free_score.scores == [0]
    @test !check_branch_fresh_prefix(branch_free_score)

    # Different anchors with the same sigma-fibre represent one branch image.
    duplicate_image = observation(Dict(
        :m0 => [:e0, :e1],
        :m1 => [:e0, :e1],
    ))
    @test finite_branch_score([duplicate_image], identity).scores == [1]

    # A finite hConv mismatch is rejected.
    bad_hconv = FiniteBranchObservation(
        [:m0], [:e0, :e1],
        _ -> Set([:e0, :e1]),
        _ -> Set{Symbol}(),
    )
    @test !check_branch_observation(bad_hconv)
    @test !check_branch_novelty_route([bad_hconv], identity)

    # A coarse identity that collapses distinct local environments is rejected.
    coarse = FiniteEnvironmentIdentity((_, _) -> :same)
    @test !check_environment_identity([first], coarse)
    @test_throws ArgumentError finite_branch_score([first], coarse)

    # Pure renaming does not create novelty when stable environment IDs agree.
    renamed_first = observation(
        Dict(:renamed_motor => [:x0, :x1]);
        environments=[:x0, :x1],
    )
    rename_identity = FiniteEnvironmentIdentity((generation, environment) ->
        generation == 1 ? environment : Dict(:x0 => :e0, :x1 => :e1)[environment])
    rename_score = finite_branch_score([first, renamed_first], rename_identity)
    @test rename_score.scores == [1, 1]
    @test rename_score.novel_counts == [1, 0]
    @test !check_shared_environment_carrier([first, renamed_first])
    @test !check_canonical_branch_novelty_route([first, renamed_first])

    # The generic trusted boundary can manufacture novelty by separating the
    # same carrier across generations.  The certified checker has no identity
    # input and therefore rejects the same false-positive claim.
    separated = FiniteEnvironmentIdentity(
        (generation, environment) -> (generation, environment))
    separated_score = finite_branch_score([first, first], separated)
    @test separated_score.scores == [1, 2]
    @test separated_score.novel_counts == [1, 1]
    @test !check_canonical_branch_novelty_route([first, first]; cutoff=2)

    # Incomplete and duplicate closed carriers are rejected.
    duplicate_carrier = FiniteBranchObservation(
        [:m0], [:e0, :e0], _ -> Set([:e0]), _ -> Set([:m0]))
    @test !check_branch_observation(duplicate_carrier)
    @test_throws ArgumentError finite_branch_score(
        FiniteBranchObservation[], identity)
end
