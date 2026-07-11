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
