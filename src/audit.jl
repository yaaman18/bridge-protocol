struct FiniteSimulation{G,H,F,P}
    source::G
    target::H
    map_state::F
    edge_path::P
end

function check_label_preserving_simulation(
    simulation::FiniteSimulation,
    edge_kinds::AbstractVector{<:OpenEdgeKind},
)
    source = simulation.source
    target = simulation.target
    all(state -> simulation.map_state(state) in target.states, source.states) || return false
    all((from, kind, to) for from in source.states, kind in edge_kinds, to in source.states) do triple
        from, kind, to = triple
        source.step(from, kind, to) || return true
        path = simulation.edge_path(from, kind, to)
        path isa OpenPath || return false
        first(path.states) == simulation.map_state(from) || return false
        last(path.states) == simulation.map_state(to) || return false
        all(==(kind), path.kinds) && check_open_path(target, path)
    end
end

struct FiniteAuditMap{I,M,S,F,A}
    implementation::I
    model::M
    simulation::S
    fingerprint::F
    assumptions::Vector{A}
end

function check_audit_map(
    audit::FiniteAuditMap,
    edge_kinds::AbstractVector{<:OpenEdgeKind},
)
    check_label_preserving_simulation(audit.simulation, edge_kinds) || return false
    implementation = audit.implementation
    model = audit.model
    map_state = audit.simulation.map_state
    all(!implementation.init(state) || model.init(map_state(state))
        for state in implementation.graph.states) || return false

    implementation_closure = _reflexive_closure(
        _positive_transitive_closure(_adjacency(implementation.graph, edge_kinds)),
    )
    model_closure = _reflexive_closure(
        _positive_transitive_closure(_adjacency(model.graph, edge_kinds)),
    )
    implementation_initial = findall(implementation.init, implementation.graph.states)
    model_initial = findall(model.init, model.graph.states)
    implementation_reachable = [
        index for index in eachindex(implementation.graph.states)
        if any(implementation_closure[source, index] for source in implementation_initial)
    ]
    model_reachable = [
        index for index in eachindex(model.graph.states)
        if any(model_closure[source, index] for source in model_initial)
    ]
    all(model_reachable) do model_index
        model_state = model.graph.states[model_index]
        any(
            map_state(implementation.graph.states[index]) == model_state
            for index in implementation_reachable
        )
    end
end

function check_no_terminal_audit_soundness(
    audit::FiniteAuditMap,
    edge_kinds::AbstractVector{<:OpenEdgeKind},
)
    check_audit_map(audit, edge_kinds) || return false
    !check_no_terminal_init(audit.model, edge_kinds) ||
        check_no_terminal_init(audit.implementation, edge_kinds)
end

function check_goal_noninterference(observe, goals, inputs)
    all(observe(first_goal, input) == observe(second_goal, input)
        for first_goal in goals, second_goal in goals, input in inputs)
end

function check_internal_factorization(observe, internal_view, decide, goals, inputs)
    all(observe(goal, input) == decide(internal_view(input))
        for goal in goals, input in inputs)
end

@enum AuditResultKind begin
    audit_proved
    audit_refuted
    audit_bounded
    audit_observed
    audit_unknown
end

struct AuditCertificate{C,F,V,D,K,T,S}
    claim::C
    subject_fingerprint::F
    abstraction_version::V
    dependencies::Vector{D}
    checker::K
    trust_boundary::T
    scope::S
    result::AuditResultKind
end
