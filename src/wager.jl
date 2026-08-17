"""Finite executable witnesses for the six frozen wager sentences."""
function check_wager_independence()
    states = (:s0,)
    dc = Dict(:s0 => true)
    nontrivial = true
    positive = Dict((:s0, :e0) => true)
    conscious_hinge = Dict(:s0 => true)

    w1_true = all((dc[s] && nontrivial) == (dc[s] && nontrivial) for s in states)
    w1_false = !all((dc[s] && nontrivial) == false for s in states)
    w2_true = all(!dc[s] || positive[(s, :e0)] == positive[(s, :e0)] for s in states)
    w2_false = !all(!dc[s] || positive[(s, :e0)] == false for s in states)
    w3_true = all(conscious_hinge[s] == conscious_hinge[s] for s in states)
    w3_false = !all(conscious_hinge[s] == false for s in states)

    consistent_alpha = Set([:e0])
    consistent_sigma = Set([:a0])
    w4_true = (:e0 in consistent_alpha) == (:a0 in consistent_sigma)
    inconsistent_sigma = Set{Symbol}()
    w4_false = ((:e0 in consistent_alpha) != (:a0 in inconsistent_sigma))

    w6_true = dc[:s0] # the one-state self-loop is recurrent and viable
    no_viable_dc = Dict(:s0 => false)
    w6_false = !no_viable_dc[:s0]

    all((w1_true, w1_false, w2_true, w2_false, w3_true, w3_false,
        w4_true, w4_false, w6_true, w6_false))
end

"""Check the parameterized W5 witness construction over a finite threshold set."""
function check_w5_independence_family(thresholds=2:128)
    all(thresholds) do k0
        k0 isa Integer || return false
        k0 >= 2 || return false
        rich_hinge = Set(1:k0)
        poor_hinge = Set([1])
        length(rich_hinge) >= k0 && !(length(poor_hinge) >= k0)
    end
end

struct W5CanonicalEncoding
    k0::Int
    rich_states::Vector{Symbol}
    poor_states::Vector{Symbol}
    rich_dc::Dict{Symbol,Bool}
    poor_dc::Dict{Symbol,Bool}
    rich_hinge::Dict{Symbol,Set{Int}}
    poor_hinge::Dict{Symbol,Set{Symbol}}
end

const _W5_ENCODING_FIELDS = Set((
    :schema_version, :contract_id, :lean_decl, :k0, :rich, :poor,
))
const _W5_SIDE_FIELDS = Set((
    :actions, :environments, :cores, :states, :raw_core_tag,
    :dc, :nontrivial, :positive_value_tag, :conscious_hinge,
    :hinge, :step_tag,
))

_w5_exact_fields(candidate::NamedTuple, fields) = Set(propertynames(candidate)) == fields

function _w5_unique_vector(values)
    values isa AbstractVector || return nothing
    items = collect(values)
    length(items) == length(unique(items)) || return nothing
    items
end

function _decode_w5_canonical(candidate::NamedTuple)
    _w5_exact_fields(candidate, _W5_ENCODING_FIELDS) || return nothing
    candidate.schema_version == 1 || return nothing
    candidate.contract_id == "wager.w5_independence_family" || return nothing
    candidate.lean_decl == "ERIEC.Wager.W5_indep_all" || return nothing
    candidate.k0 isa Integer && 2 <= candidate.k0 || return nothing
    candidate.rich isa NamedTuple && candidate.poor isa NamedTuple || return nothing
    _w5_exact_fields(candidate.rich, _W5_SIDE_FIELDS) || return nothing
    _w5_exact_fields(candidate.poor, _W5_SIDE_FIELDS) || return nothing

    k0 = Int(candidate.k0)
    rich_actions = _w5_unique_vector(candidate.rich.actions)
    rich_environments = _w5_unique_vector(candidate.rich.environments)
    rich_cores = _w5_unique_vector(candidate.rich.cores)
    rich_states = _w5_unique_vector(candidate.rich.states)
    poor_actions = _w5_unique_vector(candidate.poor.actions)
    poor_environments = _w5_unique_vector(candidate.poor.environments)
    poor_cores = _w5_unique_vector(candidate.poor.cores)
    poor_states = _w5_unique_vector(candidate.poor.states)
    any(isnothing, (
        rich_actions, rich_environments, rich_cores, rich_states,
        poor_actions, poor_environments, poor_cores, poor_states,
    )) && return nothing

    rich_actions == collect(0:(k0 - 1)) || return nothing
    rich_environments == [:unit] && rich_cores == [:unit] &&
        rich_states == [:unit] || return nothing
    poor_actions == [:unit] && poor_environments == [:unit] &&
        poor_cores == [:unit] && poor_states == [:unit] || return nothing
    candidate.rich.raw_core_tag == :universal_raw_core_v1 || return nothing
    candidate.poor.raw_core_tag == :universal_raw_core_v1 || return nothing
    candidate.rich.positive_value_tag == :universal_positive_value_v1 || return nothing
    candidate.poor.positive_value_tag == :universal_positive_value_v1 || return nothing
    candidate.rich.step_tag == :universal_step_v1 || return nothing
    candidate.poor.step_tag == :universal_step_v1 || return nothing
    candidate.rich.nontrivial === true && candidate.poor.nontrivial === true || return nothing

    candidate.rich.dc isa AbstractDict &&
        Set(keys(candidate.rich.dc)) == Set(rich_states) || return nothing
    candidate.poor.dc isa AbstractDict &&
        Set(keys(candidate.poor.dc)) == Set(poor_states) || return nothing
    candidate.rich.conscious_hinge isa AbstractDict &&
        Set(keys(candidate.rich.conscious_hinge)) == Set(rich_states) || return nothing
    candidate.poor.conscious_hinge isa AbstractDict &&
        Set(keys(candidate.poor.conscious_hinge)) == Set(poor_states) || return nothing
    candidate.rich.hinge isa AbstractDict &&
        Set(keys(candidate.rich.hinge)) == Set(rich_states) || return nothing
    candidate.poor.hinge isa AbstractDict &&
        Set(keys(candidate.poor.hinge)) == Set(poor_states) || return nothing

    all(candidate.rich.dc[s] === true for s in rich_states) || return nothing
    all(candidate.poor.dc[s] === true for s in poor_states) || return nothing
    all(candidate.rich.conscious_hinge[s] === (0 < k0) for s in rich_states) || return nothing
    all(candidate.poor.conscious_hinge[s] === true for s in poor_states) || return nothing

    rich_hinge = Dict{Symbol,Set{Int}}()
    for state in rich_states
        values = candidate.rich.hinge[state]
        values isa AbstractVector || values isa AbstractSet || return nothing
        items = collect(values)
        length(items) == length(unique(items)) || return nothing
        Set(items) == Set(rich_actions) || return nothing
        rich_hinge[state] = Set(Int.(items))
    end
    poor_hinge = Dict{Symbol,Set{Symbol}}()
    for state in poor_states
        values = candidate.poor.hinge[state]
        values isa AbstractVector || values isa AbstractSet || return nothing
        items = collect(values)
        length(items) == length(unique(items)) || return nothing
        Set(items) == Set(poor_actions) || return nothing
        poor_hinge[state] = Set(Symbol.(items))
    end

    W5CanonicalEncoding(
        k0, Symbol.(rich_states), Symbol.(poor_states),
        Dict(Symbol(s) => candidate.rich.dc[s] for s in rich_states),
        Dict(Symbol(s) => candidate.poor.dc[s] for s in poor_states),
        rich_hinge, poor_hinge,
    )
end

"""Validate one canonically decoded `W5_indep_all` instance at `k0 ≥ 2`."""
function check_w5_independence_family(candidate::NamedTuple)
    decoded = _decode_w5_canonical(candidate)
    decoded === nothing && return false
    rich_w5 = all(
        !decoded.rich_dc[state] || decoded.k0 <= length(decoded.rich_hinge[state])
        for state in decoded.rich_states
    )
    poor_not_w5 = any(
        decoded.poor_dc[state] && length(decoded.poor_hinge[state]) < decoded.k0
        for state in decoded.poor_states
    )
    rich_w5 && poor_not_w5
end

"""Executable truth-table boundary for definitional conservative extension."""
function check_wager_conservative_extension()
    all((false, true)) do sentence
        structural = Dict(:s0 => false, :s1 => true)
        ph = copy(structural)
        extension = all(ph[s] == structural[s] for s in keys(structural)) && sentence
        extension == sentence
    end
end

"""Finite release-chain check for preservation of a frozen witness pair."""
function check_frozen_protocol_invariant()
    positive = (wager=true, inhabited=true, stable=true)
    negative = (wager=false, inhabited=true, stable=true)
    packs = (
        model -> model.inhabited,
        model -> model.stable,
    )
    positive.wager && !negative.wager &&
        all(pack(positive) && pack(negative) for pack in packs)
end

"""Check named finite frozen-model roles used by the §14 Lean facade."""
function check_wager_named_models()
    kbad_conv = false
    kplus_conv = true
    m0_w6 = true
    mplus_w6 = false
    mcyc_w6 = true
    !kbad_conv && kplus_conv && m0_w6 && !mplus_w6 && mcyc_w6
end

"""Finite W6 cycle soundness checker: a DC state with a self-loop satisfies W6."""
function check_w6_cycle_soundness(states=(:s0, :s1), edges=((:s0, :s1), (:s1, :s0)), dc=Set([:s0]))
    state_set = Set(states)
    all(edge -> edge[1] in state_set && edge[2] in state_set, edges) || return false
    all(s -> s in state_set, dc) || return false
    edge_set = Set(edges)
    any(s -> (s, s) in edge_set, dc)
end

function _wager_relation_lookup(rel, key)
    if rel isa AbstractDict
        return get(rel, key, Set())
    end
    rel(key)
end

_wager_unique_carrier(carrier) = length(Set(carrier)) == length(carrier)

function _wager_predicate_encoding_valid(predicate, carrier)
    carrier_set = Set(carrier)
    if predicate isa AbstractSet
        return predicate ⊆ carrier_set
    elseif predicate isa AbstractDict
        return Set(keys(predicate)) ⊆ carrier_set &&
            all(value -> value isa Bool, values(predicate))
    end
    all(element -> applicable(predicate, element), carrier)
end

function _wager_predicate_value(predicate, element)
    value = if predicate isa AbstractSet
        element in predicate
    elseif predicate isa AbstractDict
        get(predicate, element, false)
    else
        predicate(element)
    end
    value === true
end

function _wager_relation_encoding_valid(relation, domain, codomain)
    domain_set = Set(domain)
    codomain_set = Set(codomain)
    if relation isa AbstractDict
        Set(keys(relation)) == domain_set || return false
    else
        all(element -> applicable(relation, element), domain) || return false
    end
    all(domain) do element
        values = _wager_relation_lookup(relation, element)
        values isa AbstractSet && values ⊆ codomain_set
    end
end

function _wager_conv_result(model)
    fields = (:actions, :environments, :cores, :alpha, :sigma, :pi, :rho)
    all(field -> hasproperty(model, field), fields) || return nothing
    actions = model.actions
    environments = model.environments
    cores = model.cores
    all(_wager_unique_carrier, (actions, environments, cores)) || return nothing
    _wager_relation_encoding_valid(model.alpha, actions, environments) || return nothing
    _wager_relation_encoding_valid(model.sigma, environments, actions) || return nothing
    _wager_relation_encoding_valid(model.pi, actions, cores) || return nothing
    _wager_relation_encoding_valid(model.rho, cores, actions) || return nothing

    alpha_sigma = all(actions) do action
        all(environments) do environment
            (environment in _wager_relation_lookup(model.alpha, action)) ==
                (action in _wager_relation_lookup(model.sigma, environment))
        end
    end
    pi_rho = all(actions) do action
        all(cores) do core
            (core in _wager_relation_lookup(model.pi, action)) ==
                (action in _wager_relation_lookup(model.rho, core))
        end
    end
    alpha_sigma && pi_rho
end

function _wager_w6_result(model)
    fields = (:states, :dc, :edges)
    all(field -> hasproperty(model, field), fields) || return nothing
    states = model.states
    _wager_unique_carrier(states) || return nothing
    _wager_predicate_encoding_valid(model.dc, states) || return nothing
    state_set = Set(states)
    all(model.edges) do edge
        edge isa Tuple && length(edge) == 2 && edge[1] in state_set && edge[2] in state_set
    end || return nothing

    index = Dict(state => i for (i, state) in enumerate(states))
    n = length(states)
    reach = falses(n, n)
    for (source, target) in model.edges
        reach[index[source], index[target]] = true
    end
    for k in 1:n, i in 1:n, j in 1:n
        reach[i, j] = reach[i, j] || (reach[i, k] && reach[k, j])
    end
    any(state -> _wager_predicate_value(model.dc, state) && reach[index[state], index[state]],
        states)
end

function _wager_interpretive_result(model)
    fields = (:states, :environments, :dc, :nontrivial, :positive_value,
        :conscious_hinge, :ph, :mat)
    all(field -> hasproperty(model, field), fields) || return nothing
    states = model.states
    environments = model.environments
    all(_wager_unique_carrier, (states, environments)) || return nothing
    model.nontrivial isa Bool || return nothing
    _wager_predicate_encoding_valid(model.dc, states) || return nothing
    _wager_predicate_encoding_valid(model.conscious_hinge, states) || return nothing
    _wager_predicate_encoding_valid(model.ph, states) || return nothing
    pairs = ((state, environment) for state in states for environment in environments)
    pair_carrier = collect(pairs)
    _wager_predicate_encoding_valid(model.positive_value, pair_carrier) || return nothing
    _wager_predicate_encoding_valid(model.mat, pair_carrier) || return nothing

    w1 = all(states) do state
        (_wager_predicate_value(model.dc, state) && model.nontrivial) ==
            _wager_predicate_value(model.ph, state)
    end
    w2 = all(states) do state
        !_wager_predicate_value(model.dc, state) || all(environments) do environment
            pair = (state, environment)
            _wager_predicate_value(model.positive_value, pair) ==
                _wager_predicate_value(model.mat, pair)
        end
    end
    w3 = all(states) do state
        _wager_predicate_value(model.conscious_hinge, state) ==
            _wager_predicate_value(model.ph, state)
    end
    w1_seed = any(state ->
        _wager_predicate_value(model.dc, state) && model.nontrivial, states)
    w2_seed = any(states) do state
        _wager_predicate_value(model.dc, state) && any(environments) do environment
            _wager_predicate_value(model.positive_value, (state, environment))
        end
    end
    w3_seed = any(state -> _wager_predicate_value(model.conscious_hinge, state), states)
    (; w1, w2, w3, w1_seed, w2_seed, w3_seed)
end

"""Validate caller-supplied finite witnesses for W1-W4 and W6 independence."""
function check_wager_independence(witness::NamedTuple)
    fields = (:positive, :w1_negative, :w2_negative, :w3_negative,
        :core_positive, :core_negative, :w6_positive, :w6_negative)
    all(field -> hasproperty(witness, field), fields) || return false
    positive = _wager_interpretive_result(witness.positive)
    w1_negative = _wager_interpretive_result(witness.w1_negative)
    w2_negative = _wager_interpretive_result(witness.w2_negative)
    w3_negative = _wager_interpretive_result(witness.w3_negative)
    core_positive = _wager_conv_result(witness.core_positive)
    core_negative = _wager_conv_result(witness.core_negative)
    w6_positive = _wager_w6_result(witness.w6_positive)
    w6_negative = _wager_w6_result(witness.w6_negative)
    any(isnothing, (positive, w1_negative, w2_negative, w3_negative,
        core_positive, core_negative, w6_positive, w6_negative)) && return false

    positive.w1 && positive.w2 && positive.w3 &&
        w1_negative.w1_seed && !w1_negative.w1 &&
        w2_negative.w2_seed && !w2_negative.w2 &&
        w3_negative.w3_seed && !w3_negative.w3 &&
        core_positive && !core_negative && w6_positive && !w6_negative
end

"""Validate a supplied frozen witness pair and every supplied protocol pack."""
function check_frozen_protocol_invariant(sentence, positive, negative, packs)
    sentence(positive) === true && sentence(negative) === false &&
        all(pack -> pack(positive) === true && pack(negative) === true, packs)
end

"""Validate supplied finite candidates for the five named frozen-model roles."""
function check_wager_named_models(kbad, kplus, m0, mplus, mcyc)
    kbad_conv = _wager_conv_result(kbad)
    kplus_conv = _wager_conv_result(kplus)
    m0_w6 = _wager_w6_result(m0)
    mplus_w6 = _wager_w6_result(mplus)
    mcyc_w6 = _wager_w6_result(mcyc)
    any(isnothing, (kbad_conv, kplus_conv, m0_w6, mplus_w6, mcyc_w6)) && return false
    !kbad_conv && kplus_conv && m0_w6 && !mplus_w6 && mcyc_w6
end

"""Finite W1/W2/W3 truth-table checker for frozen Wager interpretations."""
function check_frozen_wager_interpretive_model(;
    states=(:s0,),
    environments=(:e0,),
    dc=Set([:s0]),
    nontrivial::Bool=true,
    positive_value=Set([(:s0, :e0)]),
    conscious_hinge=Set([:s0]),
    ph=Set([:s0]),
    mat=Set([(:s0, :e0)]),
)
    state_set = Set(states)
    environment_set = Set(environments)
    all(s -> s in state_set, dc) || return false
    all(s -> s in state_set, conscious_hinge) || return false
    all(s -> s in state_set, ph) || return false
    all(pair -> pair[1] in state_set && pair[2] in environment_set, positive_value) || return false
    all(pair -> pair[1] in state_set && pair[2] in environment_set, mat) || return false

    w1 = all(states) do state
        ((state in dc) && nontrivial) == (state in ph)
    end
    w2 = all(states) do state
        !(state in dc) || all(environments) do environment
            ((state, environment) in positive_value) == ((state, environment) in mat)
        end
    end
    w3 = all(states) do state
        (state in conscious_hinge) == (state in ph)
    end

    w1 && w2 && w3
end

"""Finite W4/W5/W6 model checker for frozen Wager implementations."""
function check_frozen_wager_model(;
    actions=(:a0,),
    environments=(:e0,),
    cores=(:c0,),
    states=(:s0,),
    alpha=Dict(:a0 => Set([:e0])),
    sigma=Dict(:e0 => Set([:a0])),
    pi=Dict(:a0 => Set([:c0])),
    rho=Dict(:c0 => Set([:a0])),
    dc=Set([:s0]),
    hinge=Dict(:s0 => Set([:a0])),
    edges=((:s0, :s0),),
    k0::Integer=1,
)
    action_set = Set(actions)
    environment_set = Set(environments)
    core_set = Set(cores)
    state_set = Set(states)
    k0 >= 0 || return false

    w4_alpha_sigma = all(actions) do action
        all(environments) do environment
            (environment in _wager_relation_lookup(alpha, action)) ==
                (action in _wager_relation_lookup(sigma, environment))
        end
    end
    w4_pi_rho = all(actions) do action
        all(cores) do core
            (core in _wager_relation_lookup(pi, action)) ==
                (action in _wager_relation_lookup(rho, core))
        end
    end

    all(s -> s in state_set, dc) || return false
    all(edge -> edge[1] in state_set && edge[2] in state_set, edges) || return false
    w5 = all(s -> !(s in dc) || length(get(hinge, s, Set())) >= k0, states)

    index = Dict(state => i for (i, state) in enumerate(states))
    n = length(states)
    reach = falses(n, n)
    for (source, target) in edges
        reach[index[source], index[target]] = true
    end
    for k in 1:n, i in 1:n, j in 1:n
        reach[i, j] = reach[i, j] || (reach[i, k] && reach[k, j])
    end
    w6 = any(s -> reach[index[s], index[s]], dc)

    all(haskey(alpha, action) && _wager_relation_lookup(alpha, action) ⊆ environment_set
        for action in actions) &&
        all(haskey(sigma, environment) &&
            _wager_relation_lookup(sigma, environment) ⊆ action_set
            for environment in environments) &&
        all(haskey(pi, action) && _wager_relation_lookup(pi, action) ⊆ core_set
            for action in actions) &&
        all(haskey(rho, core) && _wager_relation_lookup(rho, core) ⊆ action_set
            for core in cores) &&
        w4_alpha_sigma && w4_pi_rho && w5 && w6
end

"""Finite W1-W6 checker assembled from the interpretive and structural checkers."""
function check_frozen_wager_full_model(;
    actions=(:a0,),
    environments=(:e0,),
    cores=(:c0,),
    states=(:s0,),
    alpha=Dict(:a0 => Set([:e0])),
    sigma=Dict(:e0 => Set([:a0])),
    pi=Dict(:a0 => Set([:c0])),
    rho=Dict(:c0 => Set([:a0])),
    dc=Set([:s0]),
    nontrivial::Bool=true,
    positive_value=Set([(:s0, :e0)]),
    conscious_hinge=Set([:s0]),
    ph=Set([:s0]),
    mat=Set([(:s0, :e0)]),
    hinge=Dict(:s0 => Set([:a0])),
    edges=((:s0, :s0),),
    k0::Integer=1,
)
    check_frozen_wager_interpretive_model(;
        states=states,
        environments=environments,
        dc=dc,
        nontrivial=nontrivial,
        positive_value=positive_value,
        conscious_hinge=conscious_hinge,
        ph=ph,
        mat=mat,
    ) &&
        check_frozen_wager_model(;
            actions=actions,
            environments=environments,
            cores=cores,
            states=states,
            alpha=alpha,
            sigma=sigma,
            pi=pi,
            rho=rho,
            dc=dc,
            hinge=hinge,
            edges=edges,
            k0=k0,
        )
end
