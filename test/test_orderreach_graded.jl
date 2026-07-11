@testset "ordered reachability graded dynamics and boundary" begin
    order = FinitePreorder([:near, :mid, :far], (left, right) -> begin
        rank = Dict(:near => 1, :mid => 2, :far => 3)
        rank[left] <= rank[right]
    end)

    @test upward_closure(order, Set([:mid])) == Set([:mid, :far])
    @test downward_closure(order, Set([:mid])) == Set([:near, :mid])

    world = actuated_world([
        1.0 0.0
        0.0 0.5
    ]; target=1.0, tol=1e-10)
    direction_map = DirectionMap(element -> Dict(
        :near => [[0.0, 1.0]],
        :mid => [[1.0, 0.0]],
        :far => [[1.0, 0.0], [0.5, 0.0]],
    )[element])
    ordered = ordered_reachable_world_projection(
        world,
        order,
        Set([:mid]),
        direction_map;
        tol=1e-10,
    )
    @test ordered.reachability.reachable
    @test ordered.upset == Set([:mid, :far])
    @test size(ordered.directions, 2) == 3
    @test check_ordered_wld_reachable(
        world,
        order,
        Set([:mid]),
        element -> Dict(
            :near => [0.0, 1.0],
            :mid => [1.0, 0.0],
            :far => [1.0, 0.0],
        )[element];
        tol=1e-10,
    )

    tensor = [
        1.0 0.0
        0.0 2.0
    ]
    feature_map = feature_direction_map(tensor)
    @test feature_map(1) ≈ [1.0, 0.0]
    @test feature_map(2) ≈ [0.0, 1.0]

    thin = FiniteThinCategory([1, 2, 3], <=)
    @test check_thin_category(thin)
    bad_thin = FiniteThinCategory([1, 2], (a, b) -> a < b)
    @test !check_thin_category(bad_thin)

    presheaf = GradedPresheaf(
        thin,
        w -> 1:w,
        (u, _v, x) -> min(x, u),
    )
    @test check_presheaf_identity(presheaf)
    @test check_presheaf_composition(presheaf)
    @test check_presheaf_laws(presheaf)
    four = FourPresheafSystem(presheaf, presheaf, presheaf, presheaf)
    @test check_four_presheaf_laws(four)

    doubled = GradedPresheaf(
        thin,
        w -> 2 .* collect(1:w),
        (u, _v, x) -> min(x, 2u),
    )
    transformation = PresheafNaturalTransformation(
        presheaf,
        doubled,
        (_w, x) -> 2x,
    )
    @test check_presheaf_naturality(transformation)
    @test check_presheaf_transformation(transformation)

    bad_transformation = PresheafNaturalTransformation(
        presheaf,
        doubled,
        (w, x) -> w == 1 ? 2x : 2x + 1,
    )
    @test !check_presheaf_transformation(bad_transformation)

    four_target = FourPresheafSystem(doubled, doubled, doubled, doubled)
    four_transformation = FourPresheafTransformation(
        four,
        four_target;
        alpha=(_w, x) -> 2x,
        sigma=(_w, x) -> 2x,
        pi=(_w, x) -> 2x,
        rho=(_w, x) -> 2x,
    )
    @test check_four_presheaf_transformation(four_transformation)

    relation_family = PresheafRelationFamily(
        presheaf,
        doubled,
        w -> Set((x, 2x) for x in 1:w),
    )
    @test check_presheaf_relation_family(relation_family)

    presheaf_coproduct = presheaf_transition_coproduct(
        presheaf,
        doubled,
        PresheafTransition(:double, (_w, x) -> 2x),
    )
    @test presheaf_transition_labels(presheaf_coproduct) == [:double]
    @test check_presheaf_transition_coproduct(presheaf_coproduct)
    @test check_presheaf_transition_naturality(presheaf_coproduct)
    tagged_presheaf = presheaf_coproduct_injection(presheaf_coproduct, :double, 3, 2)
    @test apply_presheaf_transition_coproduct(presheaf_coproduct, tagged_presheaf) ==
        (label=:double, grade=3, value=4)
    certification = verify_lean_certified_artifact()
    presheaf_certificate = presheaf_transition_certificate(presheaf_coproduct)
    @test presheaf_certificate.ok
    @test presheaf_certificate.labels == [:double]
    certified_presheaf = certified_presheaf_transition_coproduct(
        presheaf_coproduct,
        certification,
    )
    @test certified_presheaf.payload.kind == :PresheafTransitionCoproduct
    @test certified_presheaf.certificate.ok
    @test occursin(
        "\"naturality_ok\":true",
        certified_presheaf_transition_coproduct_json(presheaf_coproduct, certification),
    )
    presheaf_graph = certificate_dependency_graph(certified_presheaf)
    @test presheaf_graph.lean_contracts == [
        "graded.presheaf_transition_coproduct",
        "graded.presheaf_transition_naturality",
        "graded.presheaf_transition_output_copair_unique",
    ]
    @test "check_presheaf_transition_naturality" in presheaf_graph.julia_checkers

    bad_presheaf_coproduct = presheaf_transition_coproduct(
        presheaf,
        doubled,
        PresheafTransition(:bad, (w, x) -> w == 1 ? 2x : 2x + 1),
    )
    @test !check_presheaf_transition_coproduct(bad_presheaf_coproduct)
    @test !check_presheaf_transition_naturality(bad_presheaf_coproduct)
    @test !presheaf_transition_certificate(bad_presheaf_coproduct).ok
    @test_throws ArgumentError certified_presheaf_transition_coproduct(
        bad_presheaf_coproduct,
        certification,
    )

    transitions = transition_coproduct(
        GradedTransition(:shrink, x -> max(x - 1, 0)),
        GradedTransition(:grow, x -> x + 1),
    )
    @test transition_labels(transitions) == [:shrink, :grow]
    @test check_transition_coproduct(transitions, Dict(:shrink => [1, 2], :grow => [1]))
    @test coproduct_injection(transitions, :shrink, 3) == (label=:shrink, value=3)
    @test apply_transition_coproduct(transitions, (label=:shrink, value=3)) ==
        (label=:shrink, value=2)
    copair = coproduct_copair(transitions, Dict(:shrink => x -> (:s, x), :grow => x -> (:g, x)))
    @test copair((label=:grow, value=2)) == (:g, 2)
    @test_throws ArgumentError transition_coproduct(
        GradedTransition(:dup, identity),
        GradedTransition(:dup, identity),
    )

    dynamics = GradedDynamics(
        (_grade, kappa) -> setdiff(kappa, Set([:c2])),
        (_grade, epsilon) -> setdiff(epsilon, Set([:e2])),
        (grade, kappa, _epsilon) -> isempty(kappa) ? grade - 1 : grade,
    )
    initial = GradedState(Set([:c1, :c2]), Set([:e1, :e2]), 2, :s0)
    trace = graded_trace(dynamics, initial; steps=2)
    @test length(trace) == 3
    @test trace[2].kappa == Set([:c1])
    @test trace[2].epsilon == Set([:e1])
    @test first_collapse_index(trace) === nothing

    collapsing = GradedDynamics(
        (_grade, _kappa) -> Set{Symbol}(),
        (_grade, epsilon) -> epsilon,
        (grade, _kappa, _epsilon) -> grade - 1,
    )
    collapse_trace = graded_trace(collapsing, initial; steps=1)
    @test first_collapse_index(collapse_trace) == 2
    @test w_crit([1, 2, 3], grade -> grade <= 2) == 2
    @test w_crit([1, 2, 3], _ -> false) === nothing

    all_states = [:s0, :s1, :s2]
    viable = Set([:s0])
    successor = state -> state == :s0 ? :s1 : :s2
    edges = boundary_edges(all_states, viable, successor)
    @test absorbing_complement(all_states, viable) == Set([:s1, :s2])
    @test length(edges) == 1
    @test edges[1].source == :s0
    @test edges[1].target == :s1
    @test check_absorbing(all_states, Set([:s1, :s2]), successor)
end
