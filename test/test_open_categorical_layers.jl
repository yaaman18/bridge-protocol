using Test

@testset "finite open dynamics" begin
    internal = INTERNAL_EDGE
    repair = CouplingEdge(:resource)
    kinds = OpenEdgeKind[internal, repair]

    recurrent_graph = FiniteOpenGraph([:a, :b]) do source, kind, target
        (source == :a && kind == internal && target == :b) ||
            (source == :b && kind == internal && target == :b) ||
            (source == :b && kind == repair && target == :a)
    end
    recurrent_frame = FiniteOpenFrame(
        recurrent_graph,
        ==(:a),
        ==(:a),
        _ -> true,
        _ -> true,
    )

    internal_path_witness = OpenPath([:a, :b, :b], OpenEdgeKind[internal, internal])
    @test check_open_path(recurrent_graph, internal_path_witness)
    @test internal_path(internal_path_witness)
    @test path_length(internal_path_witness) == 2
    @test check_finite_internal_horizon(recurrent_frame) ==
        (holds=true, horizon=2, violating_state=nothing)
    @test check_recoverable(recurrent_frame, kinds)
    @test check_possible_live(recurrent_frame, kinds)

    lasso = FiniteLassoExecution(
        [:a, :b],
        OpenEdgeKind[internal, repair],
        1,
    )
    @test check_lasso(recurrent_graph, lasso)
    @test check_recurrent_lasso(recurrent_frame, lasso)
    @test check_fair_lasso_live(recurrent_frame, [lasso])

    fall_graph = FiniteOpenGraph([:a, :b]) do source, kind, target
        (source == :a && kind == internal && target == :b) ||
            (source == :b && kind == internal && target == :b)
    end
    fall_frame = FiniteOpenFrame(
        fall_graph,
        ==(:a),
        ==(:a),
        ==(:a),
    )
    @test check_finite_internal_horizon(fall_frame).holds
    @test !check_possible_live(fall_frame, kinds)

    bad_graph = FiniteOpenGraph([:a]) do source, kind, target
        source == :a && kind == internal && target == :a
    end
    bad_frame = FiniteOpenFrame(bad_graph, _ -> true, _ -> true, _ -> true)
    @test !check_finite_internal_horizon(bad_frame).holds
end

@testset "finite audit layer" begin
    internal = INTERNAL_EDGE
    branch = CouplingEdge(:branch)
    kinds = OpenEdgeKind[internal, branch]
    graph = FiniteOpenGraph([:r, :l, :q]) do source, kind, target
        (source == :r && kind == internal && target == :l) ||
            (source == :l && kind == internal && target == :l) ||
            (source == :q && kind == internal && target == :q) ||
            (source == :r && kind == branch && target == :q)
    end
    frame = FiniteOpenFrame(graph, ==(:r), ==(:r), ==(:r))
    simulation = FiniteSimulation(
        graph,
        graph,
        identity,
        (source, kind, target) -> OpenPath(
            [source, target],
            OpenEdgeKind[kind],
        ),
    )
    audit = FiniteAuditMap(frame, frame, simulation, "branch-v1", String[])

    @test check_label_preserving_simulation(simulation, kinds)
    @test check_audit_map(audit, kinds)
    @test check_no_terminal_init(frame, kinds)
    @test check_no_terminal_audit_soundness(audit, kinds)
    @test check_goal_noninterference((_, input) -> input^2, [:g1, :g2], 1:3)
    @test !check_goal_noninterference((goal, input) -> (goal, input), [:g1, :g2], 1:3)
    @test check_internal_factorization(
        (_, input) -> isodd(input),
        isodd,
        identity,
        [:g1, :g2],
        1:4,
    )
end

@testset "finite lineage layer" begin
    systems = collect(0:3)
    semantics = FiniteSemanticEquivalence(systems, ==)
    lineage = FiniteLineage(systems, (parent, child) -> child == parent + 1)

    @test check_semantic_equivalence(semantics)
    @test check_lineage(lineage)
    @test check_fresh_sem_prefix(lineage, semantics; start=4)
    @test !check_eventually_periodic_sem_prefix(
        lineage,
        semantics;
        start=1,
        period=1,
    )
    @test_throws ArgumentError check_eventually_periodic_sem_prefix(
        lineage,
        semantics;
        start=4,
        period=1,
    )
    @test_throws ArgumentError FiniteLineage(Int[], (parent, child) -> true)
    @test check_cofinal_over_bounds(lineage, identity, [-1, 0, 1, 2])
    @test check_produces_richer_system(
        0,
        systems,
        (parent, child) -> child == parent + 1,
        system -> system <= 3,
        identity,
    )
    @test !check_produces_richer_system(
        3,
        systems,
        (parent, child) -> child == parent + 1,
        system -> system <= 3,
        identity,
    )
end

@testset "finite theory translation and guarantees" begin
    theory = FiniteTheory(
        [:s],
        _ -> [false, true],
        _ -> [false, true],
        (model, sentence) -> model == sentence,
    )
    translation = FiniteTheoryTranslation(
        theory,
        theory,
        identity,
        (_, sentence) -> sentence,
        (_, model) -> model,
    )

    @test check_satisfaction_preserving(translation)
    @test check_conservative_translation(translation)

    profile = GuaranteeProfile(
        core_machine_checked,
        audit_simulation_sound,
        viability_fair_live,
        generative_fresh,
        translation_satisfaction_preserving,
    )
    @test profile.phenomenal_claim == :not_certified
    @test_throws ArgumentError GuaranteeProfile(
        core_machine_checked,
        audit_simulation_sound,
        viability_fair_live,
        generative_fresh,
        translation_satisfaction_preserving;
        phenomenal_claim=:certified,
    )
end
