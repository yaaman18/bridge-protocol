const CHECKER_SENSITIVITY_NEGATIVE_KINDS = Set([
    "mutated_candidate",
    "invalid_encoding",
    "countermodel",
])

"""Executable positive/negative evidence for reviewed exact finite checkers."""
function checker_sensitivity_cases()
    cases = Dict{String,NamedTuple}(
        "adjunction.rigidity" => (
            positive=() -> begin
                all_M = Set([:m1, :m2])
                all_E = Set([:e1, :e2])
                alpha = m -> m == :m1 ? Set([:e1]) : Set([:e2])
                sigma = e -> e == :e1 ? Set([:m1]) : Set([:m2])
                check_relational_rigidity(alpha, sigma, all_M, all_E)
            end,
            negative=() -> begin
                all_M = Set([:m1, :m2])
                all_E = Set([:e1, :e2])
                alpha = m -> m == :m1 ? Set([:e1]) : Set([:e2])
                invalid_sigma = _ -> all_M
                check_relational_rigidity(alpha, invalid_sigma, all_M, all_E)
            end,
            negative_kind="invalid_encoding",
        ),
        "interface.relation_linearization" => (
            positive=() -> begin
                motors = [:m1, :m2]
                environments = [:e1, :e2, :e3]
                alpha = m -> m == :m1 ? Set([:e1, :e3]) : Set([:e2])
                sigma = e -> e in (:e1, :e3) ? Set([:m1]) : Set([:m2])
                check_converse_adjoint(alpha, sigma, motors, environments)
            end,
            negative=() -> begin
                motors = [:m1, :m2]
                environments = [:e1, :e2, :e3]
                alpha = m -> m == :m1 ? Set([:e1, :e3]) : Set([:e2])
                mutated_sigma = _ -> Set([:m1, :m2])
                check_converse_adjoint(alpha, mutated_sigma, motors, environments)
            end,
            negative_kind="mutated_candidate",
        ),
        "interface.sensitivity_realization" => (
            positive=() -> begin
                motors = [:m1, :m2]
                environments = [:e1, :e2, :e3]
                alpha = m -> m == :m1 ? Set([:e1, :e3]) : Set([:e2])
                incidence = relation_incidence_matrix(alpha, motors, environments)
                check_relation_sensitivity_bridge(
                    alpha, motors, environments, x -> incidence * x, zeros(2),
                )
            end,
            negative=() -> begin
                motors = [:m1, :m2]
                environments = [:e1, :e2, :e3]
                alpha = m -> m == :m1 ? Set([:e1, :e3]) : Set([:e2])
                incidence = relation_incidence_matrix(alpha, motors, environments)
                check_relation_sensitivity_bridge(
                    alpha, motors, environments, x -> 2 .* (incidence * x), zeros(2),
                )
            end,
            negative_kind="mutated_candidate",
        ),
        "markers.classify" => (
            positive=() -> check_marker_classification(
                FMMarkers(true, false, true, true), :blindsight_analog,
            ),
            negative=() -> check_marker_classification(
                FMMarkers(true, false, true, true), :nonconscious,
            ),
            negative_kind="mutated_candidate",
        ),
        "interface.relation_naturality" => (
            positive=() -> begin
                rel = m -> m == :m1 ? Set([:e1, :e3]) : Set([:e2])
                rel_prime = u -> u == :u1 ? Set([:v1, :v3]) : Set([:v2])
                map_m = m -> m == :m1 ? :u1 : :u2
                map_e = e -> e == :e1 ? :v1 : e == :e2 ? :v2 : :v3
                check_relation_linearization_naturality(
                    rel, rel_prime, [:m1, :m2], [:e1, :e2, :e3],
                    [:u2, :u1], [:v3, :v1, :v2], map_m, map_e,
                )
            end,
            negative=() -> begin
                rel = m -> m == :m1 ? Set([:e1, :e3]) : Set([:e2])
                mutated_rel_prime = _ -> Set([:v1])
                map_m = m -> m == :m1 ? :u1 : :u2
                map_e = e -> e == :e1 ? :v1 : e == :e2 ? :v2 : :v3
                check_relation_linearization_naturality(
                    rel, mutated_rel_prime, [:m1, :m2], [:e1, :e2, :e3],
                    [:u2, :u1], [:v3, :v1, :v2], map_m, map_e,
                )
            end,
            negative_kind="mutated_candidate",
        ),
        "interface.relation_lax_naturality" => (
            positive=() -> check_relation_hom_lax_naturality(
                _ -> Set([:edge]), _ -> Set([:target]), [:source], [:edge],
                _ -> :mapped, _ -> :target,
            ),
            negative=() -> check_relation_hom_lax_naturality(
                _ -> Set([:edge]), _ -> Set{Symbol}(), [:source], [:edge],
                _ -> :mapped, _ -> :target,
            ),
            negative_kind="mutated_candidate",
        ),
        "bridge.hinge_object_classifier" => (
            positive=() -> check_hinge_classifying_loop(
                _ -> Set([:m]), _ -> Set([:m]), _ -> Set([:c]),
                _ -> Set([:e]), :s, ones(1, 1),
            ).contract_holds,
            negative=() -> check_hinge_classifying_loop(
                _ -> Set([:m]), _ -> Set([:m]), _ -> Set([:c]),
                _ -> Set([:e]), :s, zeros(1, 1),
            ).contract_holds,
            negative_kind="mutated_candidate",
        ),
        "bridge.hinge_lax_map" => (
            positive=() -> check_hinge_classifying_loop_lax(
                _ -> Set([:m]), _ -> Set([:m]), _ -> Set([:c]),
                _ -> Set([:e]), :s,
                _ -> Set([:m]), _ -> Set([:m]), _ -> Set([:c]),
                _ -> Set([:e]), :s,
                ones(1, 1), ones(1, 1),
            ).contract_holds,
            negative=() -> check_hinge_classifying_loop_lax(
                _ -> Set([:m]), _ -> Set([:m]), _ -> Set([:c]),
                _ -> Set([:e]), :s,
                _ -> Set([:m]), _ -> Set([:m]), _ -> Set([:c]),
                _ -> Set([:e]), :s,
                ones(1, 1), zeros(1, 1),
            ).contract_holds,
            negative_kind="mutated_candidate",
        ),
        "bridge.hinge_thin_functor" => (
            positive=() -> check_hinge_classifier_functor_laws(
                _ -> Set([:m]), _ -> Set([:m]), _ -> Set([:c]),
                _ -> Set([:e]), :s, ones(1, 1),
            ).contract_holds,
            negative=() -> check_hinge_classifier_functor_laws(
                _ -> Set([:m]), _ -> Set([:m]), _ -> Set([:c]),
                _ -> Set([:e]), :s, zeros(1, 1),
            ).contract_holds,
            negative_kind="mutated_candidate",
        ),
        "bridge.hinge_strict_functor" => (
            positive=() -> check_strict_hinge_classifier_intertwining(
                _ -> Set([:m]), _ -> Set([:m]), _ -> Set([:c]),
                _ -> Set([:e]), :s,
                _ -> Set([:m]), _ -> Set([:m]), _ -> Set([:c]),
                _ -> Set([:e]), :s,
                ones(1, 1), ones(1, 1),
            ).contract_holds,
            negative=() -> check_strict_hinge_classifier_intertwining(
                _ -> Set([:m]), _ -> Set([:m]), _ -> Set([:c]),
                _ -> Set([:e]), :s,
                _ -> Set{Symbol}(), _ -> Set([:m]), _ -> Set([:c]),
                _ -> Set([:e]), :s,
                ones(1, 1), ones(1, 1),
            ).contract_holds,
            negative_kind="invalid_encoding",
        ),
        "bridge.hinge_hilbert_functor" => (
            positive=() -> check_hinge_hilbert_functor(
                _ -> Set([:m]), _ -> Set([:m]), _ -> Set([:c]),
                _ -> Set([:e]), :s, ones(1, 1),
            ).contract_holds,
            negative=() -> check_hinge_hilbert_functor(
                _ -> Set([:m]), _ -> Set([:m]), _ -> Set([:c]),
                _ -> Set([:e]), :s, zeros(1, 1),
            ).contract_holds,
            negative_kind="mutated_candidate",
        ),
        "bridge.hinge_structural_functor" => (
            positive=() -> structural_hinge_isomorphism_witness(
                _ -> Set([:m]), _ -> Set([:m]), _ -> Set([:c]),
                _ -> Set([:e]), :s, ones(1, 1),
            ).contract_holds,
            negative=() -> structural_hinge_isomorphism_witness(
                _ -> Set([:m]), _ -> Set([:m]), _ -> Set([:c]),
                _ -> Set([:e]), :s, zeros(1, 1),
            ).contract_holds,
            negative_kind="mutated_candidate",
        ),
        "viability.closure_object" => (
            positive=() -> begin
                step = (source, target) ->
                    (source == :a && target == :b) || (source == :b && target == :b)
                check_viability_closure(
                    [:a, :b, :c], step, state -> state in (:a, :b),
                ).contract_holds
            end,
            negative=() -> begin
                step = (source, target) -> source == :a && target == :c
                check_viability_closure(
                    [:a, :b, :c], step, state -> state == :a,
                ).contract_holds
            end,
            negative_kind="invalid_encoding",
        ),
        "viability.closure_functor" => (
            positive=() -> _checker_sensitivity_closure_functor(true),
            negative=() -> begin
                source = [:a, :b, :c]
                target = [:x, :y]
                check_viability_closure_naturality(
                    source,
                    target,
                    Dict(:a => :x, :b => :x, :c => :y),
                    (_source, _target) -> false,
                    (_source, _target) -> false,
                    _ -> false,
                    _ -> false,
                    powerset(Set(source)),
                ).contract_holds
            end,
            negative_kind="invalid_encoding",
        ),
        "viability.relational_frame" => (
            positive=() -> begin
                step = (source, target) ->
                    (source == :a && target == :b) || (source == :b && target == :b)
                check_viability_relational_frame(
                    [:a, :b, :c], step, state -> state in (:a, :b),
                ).contract_holds
            end,
            negative=() -> begin
                step = (source, target) -> source == :a && target == :c
                check_viability_relational_frame(
                    [:a, :b, :c], step, state -> state == :a,
                ).contract_holds
            end,
            negative_kind="invalid_encoding",
        ),
        "layers.viable_to_hilbert" => (
            positive=() -> begin
                step = (source, target) ->
                    (source == :a && target == :b) || (source == :b && target == :b)
                check_layer_composition(
                    [:a, :b, :c], step, state -> state in (:a, :b),
                ).contract_holds
            end,
            negative=() -> begin
                step = (source, target) -> source == :a && target == :c
                check_layer_composition(
                    [:a, :b, :c], step, state -> state == :a,
                ).contract_holds
            end,
            negative_kind="invalid_encoding",
        ),
        "grading.const_presheaf_antitone" => (
            positive=() -> check_const_presheaf_antitone(
                (rank, left, right) -> left == right && rank <= 1,
                0:2, <=, 1:2, 1:2,
            ),
            negative=() -> check_const_presheaf_antitone(
                (rank, left, right) -> left == right && rank >= 1,
                0:2, <=, 1:2, 1:2,
            ),
            negative_kind="countermodel",
        ),
        "hinge.act" => (
            positive=() -> check_hinge(
                c -> c == :c1 ? Set([:m1]) : Set([:m2]),
                e -> e == :e1 ? Set([:m1]) : Set([:m2]),
                _ -> Set([:c1]), _ -> Set([:e1]), :s,
            ),
            negative=() -> check_hinge(
                c -> c == :c1 ? Set([:m1]) : Set([:m2]),
                e -> e == :e1 ? Set([:m1]) : Set([:m2]),
                _ -> Set([:c1]), _ -> Set{Symbol}(), :s,
            ),
            negative_kind="countermodel",
        ),
        "decomp.copair_unique" => (
            positive=() -> check_copair_unique(
                x -> x + 1, x -> 2x,
                tagged -> first(tagged) === :left ? last(tagged) + 1 : 2 * last(tagged),
                1:3, 1:3,
            ),
            negative=() -> check_copair_unique(
                x -> x + 1, x -> 2x, tagged -> last(tagged), 1:3, 1:3,
            ),
            negative_kind="mutated_candidate",
        ),
        "graded.presheaf_transition_naturality" => (
            positive=() -> _checker_sensitivity_presheaf_naturality(false),
            negative=() -> _checker_sensitivity_presheaf_naturality(true),
            negative_kind="mutated_candidate",
        ),
        "graded.presheaf_transition_output_copair_unique" => (
            positive=() -> _checker_sensitivity_presheaf_output_copair(false),
            negative=() -> _checker_sensitivity_presheaf_output_copair(true),
            negative_kind="mutated_candidate",
        ),
        "body.no_terminal_setpoint" => (
            positive=() -> check_m4_no_terminal_setpoint(SetPointDiagram([:seek, :probe], ==)),
            negative=() -> check_m4_no_terminal_setpoint(SetPointDiagram(
                [:seek, :target],
                (source, candidate) -> source == candidate || candidate == :target,
            )),
            negative_kind="countermodel",
        ),
        "reference_models.v5_1" => (
            positive=() -> check_reference_models(
                (
                    states=[:s0, :s1, :s2],
                    next=Dict(:s0 => :s1, :s1 => :s2, :s2 => :s2),
                ),
            ).v5_1_contract_holds,
            negative=() -> begin
                mutated = (
                    states=[:s0, :s1, :s2],
                    next=Dict(:s0 => :s0, :s1 => :s2, :s2 => :s2),
                )
                check_reference_models(mutated).v5_1_contract_holds
            end,
            negative_kind="mutated_candidate",
        ),
        "wager.interpretive_model_checker" => (
            positive=() -> check_frozen_wager_interpretive_model(),
            negative=() -> check_frozen_wager_interpretive_model(ph=Set{Symbol}()),
            negative_kind="countermodel",
        ),
        "wager.finite_model_checker" => (
            positive=() -> check_frozen_wager_model(),
            negative=() -> check_frozen_wager_model(k0=2),
            negative_kind="countermodel",
        ),
        "wager.full_model_checker" => (
            positive=() -> check_frozen_wager_full_model(),
            negative=() -> check_frozen_wager_full_model(k0=2),
            negative_kind="countermodel",
        ),
        "richness.branch" => (
            positive=() -> is_branch_point(),
            negative=() -> is_branch_point(Dict(:m0 => Set([:e0])), :m0),
            negative_kind="countermodel",
        ),
        "generation.finite_branch_score" => (
            positive=() -> _checker_sensitivity_finite_branch_score(false),
            negative=() -> _checker_sensitivity_finite_branch_score(true),
            negative_kind="mutated_candidate",
        ),
    )
    Dict(
        id => merge(case, (tolerance_assumption=nothing,))
        for (id, case) in cases
    )
end

function _checker_sensitivity_finite_branch_score(mutated::Bool)
    make_observation(fibre) = FiniteBranchObservation(
        [:m0], [:e0, :e1, :e2],
        _ -> Set(fibre),
        environment -> environment in fibre ? Set([:m0]) : Set{Symbol}(),
    )
    observations = [
        make_observation([:e0, :e1]),
        make_observation([:e0]),
        make_observation([:e0, :e1, :e2]),
    ]
    identity = FiniteEnvironmentIdentity((_, environment) -> environment)
    check_finite_branch_score(
        observations, identity;
        scores=mutated ? [1, 1, 3] : [1, 1, 2],
        novel_counts=[1, 0, 1],
        lost_counts=[0, 1, 0],
    )
end

function _checker_sensitivity_closure_functor(complete_subsets::Bool)
    source_states = [:a, :b, :c]
    target_states = [:x, :y, :z]
    mapping = Dict(:a => :y, :b => :z, :c => :x)
    source_step = (source, target) ->
        (source == :a && target == :b) || (source == :b && target == :b)
    target_step = (source, target) ->
        (source == :y && target == :z) || (source == :z && target == :z)
    subsets = complete_subsets ? powerset(Set(source_states)) : [Set{Symbol}()]
    check_viability_closure_naturality(
        source_states,
        target_states,
        mapping,
        source_step,
        target_step,
        state -> state in (:a, :b),
        state -> state in (:y, :z),
        subsets,
    ).contract_holds
end

function _checker_sensitivity_presheaf_naturality(mutated::Bool)
    thin = FiniteThinCategory([1, 2, 3], <=)
    source = GradedPresheaf(thin, w -> 1:w, (u, _v, x) -> min(x, u))
    target = GradedPresheaf(thin, w -> 2 .* collect(1:w), (u, _v, x) -> min(x, 2u))
    component = mutated ?
        ((w, x) -> w == 1 ? 2x : 2x + 1) :
        ((_w, x) -> 2x)
    coproduct = presheaf_transition_coproduct(
        source, target, PresheafTransition(:candidate, component),
    )
    check_presheaf_transition_naturality(coproduct)
end

function _checker_sensitivity_presheaf_output_copair(mutated::Bool)
    thin = FiniteThinCategory([1, 2], <=)
    source = GradedPresheaf(thin, w -> 1:w, (u, _v, x) -> min(x, u))
    target = GradedPresheaf(thin, w -> 2 .* collect(1:w), (u, _v, x) -> min(x, 2u))
    coproduct = presheaf_transition_coproduct(
        source, target, PresheafTransition(:double, (_w, x) -> 2x),
    )
    handlers = (label, value) -> (label, value + 1)
    candidate = mutated ?
        (tagged -> (:mutated, tagged.value)) :
        (tagged -> handlers(tagged.label, tagged.value))
    check_presheaf_transition_coproduct(
        coproduct, 2, handlers, candidate,
    ).contract_holds
end

function _checker_sensitivity_reference_candidate()
    (
        states=[:s0, :s1, :s2],
        next=Dict(:s0 => :s1, :s1 => :s2, :s2 => :s2),
        config=Dict(
            :s0 => (kappa=Set([:c]), epsilon=Set([:e]), rank=:bottom),
            :s1 => (kappa=Set([:c]), epsilon=Set([:e]), rank=:top),
            :s2 => (kappa=Set{Symbol}(), epsilon=Set{Symbol}(), rank=:top),
        ),
        world_loop=ones(1, 1),
        normalized_value=1 // 1,
        top_phi=Set{Nothing}(),
        top_theta=Set{Nothing}(),
        drift=(w, kappa) -> (!w && !isempty(kappa)) || w,
        external=(_source, _target) -> false,
        core=state -> state == :s2 ? Set{Symbol}() : Set([:c]),
        multi_alpha=_ -> Set([false, true]),
        collapse_initial=(
            kappa=Set([nothing]), epsilon=Set([false, true]), rank=false,
        ),
        collapse_update=_ -> (
            kappa=Set{Nothing}(), epsilon=Set{Bool}(), rank=true,
        ),
        observe=_ -> nothing,
        region=Set([false]),
        markers=(fm1=true, fm2=false, fm3=true, fm4=true),
        reaches=(source, target) -> source == target,
    )
end
