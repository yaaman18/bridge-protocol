struct GradedState{C,E,W,S}
    kappa::Set{C}
    epsilon::Set{E}
    grade::W
    raw::S
end

struct FiniteThinCategory{W,F}
    objects::Vector{W}
    leq::F

    function FiniteThinCategory(objects::AbstractVector{W}, leq::F) where {W,F}
        length(unique(objects)) == length(objects) ||
            throw(ArgumentError("thin category objects must be unique"))
        new{W,F}(collect(objects), leq)
    end
end

struct GradedPresheaf{W,FO,FR}
    category::FiniteThinCategory{W}
    fiber::FO
    restrict::FR
end

struct FourPresheafSystem{A,S,P,R}
    alpha::A
    sigma::S
    pi::P
    rho::R
end

struct PresheafNaturalTransformation{S,T,C}
    source::S
    target::T
    component::C
end

struct FourPresheafTransformation{S,T,A,Si,P,R}
    source::S
    target::T
    alpha::A
    sigma::Si
    pi::P
    rho::R
end

struct PresheafRelationFamily{S,T,R}
    source::S
    target::T
    relation::R
end

struct GradedTransition{L,F}
    label::L
    map::F
end

struct PresheafTransition{L,C}
    label::L
    component::C
end

struct TransitionCoproduct{T}
    transitions::Vector{T}

    function TransitionCoproduct{T}(transitions::Vector{T}) where {T}
        labels = [transition.label for transition in transitions]
        length(unique(labels)) == length(labels) ||
            throw(ArgumentError("transition labels must be unique"))
        new{T}(transitions)
    end
end

struct PresheafTransitionCoproduct{S,T,R}
    source::S
    target::T
    transitions::Vector{R}

    function PresheafTransitionCoproduct{S,T,R}(
        source::S,
        target::T,
        transitions::Vector{R},
    ) where {S,T,R}
        labels = [transition.label for transition in transitions]
        length(unique(labels)) == length(labels) ||
            throw(ArgumentError("transition labels must be unique"))
        new{S,T,R}(source, target, transitions)
    end
end

struct GradedDynamics{FC,FE,FD}
    component_operator::FC
    environment_operator::FE
    drift::FD
end

psi_step(operator, set::Set) = set ∩ operator(set)

sensory_psi_step(alpha_rel, sigma_rel, epsilon::Set) =
    epsilon ∩ T_prime(alpha_rel, sigma_rel, epsilon)

function graded_step(dynamics::GradedDynamics, state::GradedState)
    next_kappa = state.kappa ∩ dynamics.component_operator(state.grade, state.kappa)
    next_epsilon = state.epsilon ∩ dynamics.environment_operator(state.grade, state.epsilon)
    next_grade = dynamics.drift(state.grade, next_kappa, next_epsilon)
    GradedState(next_kappa, next_epsilon, next_grade, state.raw)
end

function graded_trace(dynamics::GradedDynamics, initial::GradedState; steps::Integer)
    steps >= 0 || throw(ArgumentError("steps must be non-negative"))
    states = GradedState[initial]
    current = initial
    for _ in 1:steps
        current = graded_step(dynamics, current)
        push!(states, current)
    end
    states
end

function w_crit(grades, predicate)
    selected = [grade for grade in grades if predicate(grade)]
    isempty(selected) ? nothing : last(selected)
end

function first_collapse_index(trace; require_kappa::Bool=true, require_epsilon::Bool=true)
    findfirst(trace) do state
        (require_kappa && isempty(state.kappa)) ||
            (require_epsilon && isempty(state.epsilon))
    end
end

function check_thin_category(category::FiniteThinCategory)
    objects = category.objects
    reflexive = all(w -> category.leq(w, w), objects)
    transitive = all(
        !(category.leq(u, v) && category.leq(v, w)) || category.leq(u, w)
        for u in objects, v in objects, w in objects
    )
    reflexive && transitive
end

function check_presheaf_identity(presheaf::GradedPresheaf)
    check_thin_category(presheaf.category) || return false
    all(presheaf.restrict(w, w, x) == x
        for w in presheaf.category.objects
        for x in presheaf.fiber(w))
end

function check_presheaf_composition(presheaf::GradedPresheaf)
    check_thin_category(presheaf.category) || return false
    all(
        !(
            presheaf.category.leq(u, v) &&
            presheaf.category.leq(v, w)
        ) ||
            presheaf.restrict(u, v, presheaf.restrict(v, w, x)) ==
                presheaf.restrict(u, w, x)
        for u in presheaf.category.objects
        for v in presheaf.category.objects
        for w in presheaf.category.objects
        for x in presheaf.fiber(w)
    )
end

check_presheaf_laws(presheaf::GradedPresheaf) =
    check_presheaf_identity(presheaf) && check_presheaf_composition(presheaf)

function check_four_presheaf_laws(system::FourPresheafSystem)
    check_presheaf_laws(system.alpha) &&
        check_presheaf_laws(system.sigma) &&
        check_presheaf_laws(system.pi) &&
        check_presheaf_laws(system.rho)
end

function _same_thin_category(left::FiniteThinCategory, right::FiniteThinCategory)
    left.objects == right.objects || return false
    all(left.leq(u, v) == right.leq(u, v) for u in left.objects, v in left.objects)
end

function check_presheaf_naturality(transformation::PresheafNaturalTransformation)
    source = transformation.source
    target = transformation.target
    _same_thin_category(source.category, target.category) || return false
    check_presheaf_laws(source) && check_presheaf_laws(target) || return false

    all(
        !source.category.leq(u, v) ||
            target.restrict(u, v, transformation.component(v, x)) ==
                transformation.component(u, source.restrict(u, v, x))
        for u in source.category.objects
        for v in source.category.objects
        for x in source.fiber(v)
    )
end

function check_presheaf_transformation(transformation::PresheafNaturalTransformation)
    source = transformation.source
    target = transformation.target
    _same_thin_category(source.category, target.category) || return false
    all(
        transformation.component(w, x) in target.fiber(w)
        for w in source.category.objects
        for x in source.fiber(w)
    ) && check_presheaf_naturality(transformation)
end

function FourPresheafTransformation(
    source::FourPresheafSystem,
    target::FourPresheafSystem;
    alpha,
    sigma,
    pi,
    rho,
)
    FourPresheafTransformation(
        source,
        target,
        PresheafNaturalTransformation(source.alpha, target.alpha, alpha),
        PresheafNaturalTransformation(source.sigma, target.sigma, sigma),
        PresheafNaturalTransformation(source.pi, target.pi, pi),
        PresheafNaturalTransformation(source.rho, target.rho, rho),
    )
end

function check_four_presheaf_transformation(transformation::FourPresheafTransformation)
    check_four_presheaf_laws(transformation.source) &&
        check_four_presheaf_laws(transformation.target) &&
        check_presheaf_transformation(transformation.alpha) &&
        check_presheaf_transformation(transformation.sigma) &&
        check_presheaf_transformation(transformation.pi) &&
        check_presheaf_transformation(transformation.rho)
end

function check_presheaf_relation_family(family::PresheafRelationFamily)
    source = family.source
    target = family.target
    _same_thin_category(source.category, target.category) || return false
    check_presheaf_laws(source) && check_presheaf_laws(target) || return false

    all(
        !source.category.leq(u, v) || all(
            (source.restrict(u, v, first(pair)), target.restrict(u, v, last(pair))) in
                family.relation(u)
            for pair in family.relation(v)
        )
        for u in source.category.objects
        for v in source.category.objects
    )
end

function TransitionCoproduct(transitions::AbstractVector)
    copied = collect(transitions)
    TransitionCoproduct{eltype(copied)}(copied)
end

transition_coproduct(transitions::GradedTransition...) =
    TransitionCoproduct(collect(transitions))

transition_labels(coproduct::TransitionCoproduct) =
    [transition.label for transition in coproduct.transitions]

function _find_transition(coproduct::TransitionCoproduct, label)
    index = findfirst(transition -> transition.label == label, coproduct.transitions)
    index === nothing && throw(ArgumentError("unknown transition label: $label"))
    coproduct.transitions[index]
end

function coproduct_injection(coproduct::TransitionCoproduct, label, value)
    _find_transition(coproduct, label)
    (label=label, value=value)
end

function apply_transition_coproduct(coproduct::TransitionCoproduct, tagged)
    transition = _find_transition(coproduct, tagged.label)
    (label=tagged.label, value=transition.map(tagged.value))
end

function coproduct_copair(coproduct::TransitionCoproduct, handlers)
    tagged -> begin
        _find_transition(coproduct, tagged.label)
        handler = get(handlers, tagged.label, nothing)
        handler === nothing && throw(ArgumentError("missing handler for transition label: $(tagged.label)"))
        handler(tagged.value)
    end
end

check_transition_coproduct(coproduct::TransitionCoproduct) =
    length(unique(transition_labels(coproduct))) == length(coproduct.transitions)

function check_transition_coproduct(coproduct::TransitionCoproduct, samples)
    check_transition_coproduct(coproduct) || return false
    all(label in transition_labels(coproduct) for label in keys(samples)) || return false
    all(
        apply_transition_coproduct(
            coproduct,
            coproduct_injection(coproduct, label, value),
        ).label == label
        for (label, values) in pairs(samples)
        for value in values
    )
end

function PresheafTransitionCoproduct(
    source::GradedPresheaf,
    target::GradedPresheaf,
    transitions::AbstractVector,
)
    copied = collect(transitions)
    PresheafTransitionCoproduct{
        typeof(source),
        typeof(target),
        eltype(copied),
    }(source, target, copied)
end

presheaf_transition_coproduct(
    source::GradedPresheaf,
    target::GradedPresheaf,
    transitions::PresheafTransition...,
) = PresheafTransitionCoproduct(source, target, collect(transitions))

presheaf_transition_labels(coproduct::PresheafTransitionCoproduct) =
    [transition.label for transition in coproduct.transitions]

function _find_presheaf_transition(coproduct::PresheafTransitionCoproduct, label)
    index = findfirst(transition -> transition.label == label, coproduct.transitions)
    index === nothing && throw(ArgumentError("unknown transition label: $label"))
    coproduct.transitions[index]
end

function presheaf_coproduct_injection(
    coproduct::PresheafTransitionCoproduct,
    label,
    grade,
    value,
)
    _find_presheaf_transition(coproduct, label)
    value in coproduct.source.fiber(grade) ||
        throw(ArgumentError("value is not in source fiber at grade $grade"))
    (label=label, grade=grade, value=value)
end

function apply_presheaf_transition_coproduct(coproduct::PresheafTransitionCoproduct, tagged)
    transition = _find_presheaf_transition(coproduct, tagged.label)
    output = transition.component(tagged.grade, tagged.value)
    output in coproduct.target.fiber(tagged.grade) ||
        throw(ArgumentError("transition output is not in target fiber at grade $(tagged.grade)"))
    (label=tagged.label, grade=tagged.grade, value=output)
end

function check_presheaf_transition_coproduct(coproduct::PresheafTransitionCoproduct)
    source = coproduct.source
    target = coproduct.target
    _same_thin_category(source.category, target.category) || return false
    check_presheaf_laws(source) && check_presheaf_laws(target) || return false
    length(unique(presheaf_transition_labels(coproduct))) == length(coproduct.transitions) || return false

    all(
        transition.component(w, x) in target.fiber(w)
        for transition in coproduct.transitions
        for w in source.category.objects
        for x in source.fiber(w)
    )
end

function check_presheaf_transition_naturality(coproduct::PresheafTransitionCoproduct)
    check_presheaf_transition_coproduct(coproduct) || return false
    source = coproduct.source
    target = coproduct.target
    all(
        !source.category.leq(u, v) ||
            target.restrict(u, v, transition.component(v, x)) ==
                transition.component(u, source.restrict(u, v, x))
        for transition in coproduct.transitions
        for u in source.category.objects
        for v in source.category.objects
        for x in source.fiber(v)
    )
end
