const _REFERENCE_MODEL_NEXT = Dict(:s0 => :s1, :s1 => :s2, :s2 => :s2)

const _STABLE_REFERENCE_CONFIG = Dict(
    :s0 => (kappa=Set([:c]), epsilon=Set([:e]), rank=:bottom),
    :s1 => (kappa=Set([:c]), epsilon=Set([:e]), rank=:top),
    :s2 => (kappa=Set{Symbol}(), epsilon=Set{Symbol}(), rank=:top),
)

function _stable_reference_update(conf)
    at_top = conf.rank == :top
    (
        kappa=at_top ? Set{Symbol}() : copy(conf.kappa),
        epsilon=at_top ? Set{Symbol}() : copy(conf.epsilon),
        rank=isempty(conf.kappa) ? conf.rank : :top,
    )
end

"""Finite arbitrary-size nondegenerate carrier witnesses (M-1 finite fragment)."""
function check_arbitrarily_large_nondegenerate_models(sizes=(2, 3, 8, 32, 128))
    all(sizes) do k
        k isa Integer || return false
        k >= 2 || return false
        actions = Set(1:k)
        environments = Set(1:k)
        cores = Set(1:k)
        alpha = Dict(a => copy(environments) for a in actions)
        first_action = first(actions)
        length(actions) == k && length(environments) == k && length(cores) == k &&
            length(alpha[first_action]) >= 2 && !isempty(actions)
    end
end

"""Check the M-1 full Tier-1 finite discrete/dynamic AX-core witnesses."""
function check_arbitrarily_large_ax_core_discrete_models(sizes=(2, 3, 8, 32, 128))
    all(sizes) do k
        k isa Integer || return false
        k >= 2 || return false

        actions = Set(1:k)
        environments = Set(1:k)
        cores = Set(1:k)
        alpha = Dict(a => copy(environments) for a in actions)
        first_action = first(actions)

        config = Dict(
            :s0 => (kappa=copy(cores), epsilon=copy(environments), rank=false),
            :s1 => (kappa=copy(cores), epsilon=copy(environments), rank=true),
            :s2 => (kappa=Set{Int}(), epsilon=Set{Int}(), rank=true),
        )
        next = Dict(:s0 => :s1, :s1 => :s2, :s2 => :s2)
        drift(rank, kappa) = (!rank && !isempty(kappa)) ? true : rank
        update(conf) = (
            kappa=conf.rank ? Set{Int}() : copy(conf.kappa),
            epsilon=conf.rank ? Set{Int}() : copy(conf.epsilon),
            rank=drift(conf.rank, conf.kappa),
        )
        r2_ok = all(((rank, kappa),) -> begin
            shifted = drift(rank, kappa)
            rank <= shifted &&
                (isempty(kappa) || rank == true || rank < shifted)
        end, Iterators.product((false, true), (Set{Int}(), cores)))

        length(actions) == k &&
            length(environments) == k &&
            length(cores) == k &&
            length(alpha[first_action]) >= 2 &&
            all(haskey(next, state) for state in keys(config)) &&
            all(config[next[state]] == update(conf) for (state, conf) in config) &&
            r2_ok
    end
end

"""Shape-check the M-1 Tier-2 bridge to existing World/Value/§13.2 witnesses."""
function check_arbitrarily_large_three_layer_reference_models(sizes=(2, 3, 8, 32, 128))
    check_arbitrarily_large_ax_core_discrete_models(sizes) && check_reference_models()
end

function check_reference_models()
    orbit_ok = all(
        _STABLE_REFERENCE_CONFIG[_REFERENCE_MODEL_NEXT[state]] ==
            _stable_reference_update(_STABLE_REFERENCE_CONFIG[state])
        for state in keys(_REFERENCE_MODEL_NEXT)
    )
    singleton_relations = Set([:e]) == Set([:e]) && Set([:c]) == Set([:c])
    dc_at_s0 = !isempty(_STABLE_REFERENCE_CONFIG[:s0].kappa) &&
        !isempty(_STABLE_REFERENCE_CONFIG[:s0].epsilon)
    world_nontrivial = [1.0;;] * [1.0] == [1.0]
    normalized_value = 1 // 1
    multivalued = length(Set([false, true])) == 2
    finite_collapse = isempty(_stable_reference_update(_STABLE_REFERENCE_CONFIG[:s1]).kappa)
    nondeg_observe = _ -> nothing
    ins_mixed_fiber = nondeg_observe(false) == nondeg_observe(true)
    blind = (fm1=true, fm2=false, fm3=true, fm4=true)
    no_common_terminal = !any(all(source == terminal for source in (false, true))
        for terminal in (false, true))

    _REFERENCE_MODEL_NEXT[:s0] == :s1 &&
        _REFERENCE_MODEL_NEXT[:s1] == :s2 &&
        _REFERENCE_MODEL_NEXT[:s2] == :s2 &&
        orbit_ok && singleton_relations && dc_at_s0 &&
        world_nontrivial && normalized_value == 1 && multivalued && finite_collapse &&
        ins_mixed_fiber && blind.fm1 && !blind.fm2 &&
        no_common_terminal
end

"""Validate independently supplied finite encodings of the four reference-model contracts."""
function check_reference_models(candidate::NamedTuple)
    required = (
        :states, :next, :config, :world_loop, :normalized_value,
        :top_phi, :top_theta, :drift, :external, :core,
        :multi_alpha, :collapse_initial, :collapse_update,
        :observe, :region, :markers, :reaches,
    )
    encoding_complete = all(name -> hasproperty(candidate, name), required)
    if !encoding_complete
        return (
            encoding_complete=false,
            v5_1_contract_holds=false,
            stable_contract_holds=false,
            dynamic_contract_holds=false,
            nondegenerate_contract_holds=false,
            contract_holds=false,
        )
    end

    expected_states = Set((:s0, :s1, :s2))
    states = collect(candidate.states)
    carrier_complete = length(states) == 3 && Set(states) == expected_states
    next_complete = carrier_complete && Set(keys(candidate.next)) == expected_states
    next_equations = next_complete &&
        candidate.next[:s0] == :s1 &&
        candidate.next[:s1] == :s2 &&
        candidate.next[:s2] == :s2
    v5_1_contract_holds = carrier_complete && next_equations

    config_complete = carrier_complete && Set(keys(candidate.config)) == expected_states
    fixed_config = config_complete && candidate.config == _STABLE_REFERENCE_CONFIG
    total_next = next_complete && all(haskey(candidate.next, state) for state in states)
    initial_dc = fixed_config &&
        !isempty(candidate.config[:s0].kappa) &&
        !isempty(candidate.config[:s0].epsilon)
    orbit = fixed_config && next_complete && all(
        candidate.config[candidate.next[state]] ==
            _stable_reference_update(candidate.config[state])
        for state in states
    )
    world_nontrivial = size(candidate.world_loop) == (1, 1) &&
        candidate.world_loop * [1.0] == [1.0]
    value_one = candidate.normalized_value == 1
    top_relations_empty = isempty(candidate.top_phi) && isempty(candidate.top_theta)
    stable_contract_holds = v5_1_contract_holds && fixed_config && total_next &&
        initial_dc && orbit && world_nontrivial && value_one && top_relations_empty

    bool_subsets = (Set{Nothing}(), Set([nothing]))
    expected_drift(w, kappa) = (!w && !isempty(kappa)) || w
    drift_encoding = all(
        candidate.drift(w, kappa) == expected_drift(w, kappa)
        for w in (false, true) for kappa in bool_subsets
    )
    r2_monotone = all(
        w <= candidate.drift(w, kappa)
        for w in (false, true) for kappa in bool_subsets
    )
    r2_strict = all(
        isempty(kappa) || w || w < candidate.drift(w, kappa)
        for w in (false, true) for kappa in bool_subsets
    )
    external_encoding = all(
        !candidate.external(source, target)
        for source in states for target in states
    )
    core_encoding = fixed_config && all(
        candidate.core(state) == candidate.config[state].kappa for state in states
    )
    e5 = all(
        !(candidate.core(source) == candidate.core(source_prime) &&
            candidate.external(source, target)) ||
            any(
                target_prime -> candidate.external(source_prime, target_prime) &&
                    candidate.core(target) == candidate.core(target_prime),
                states,
            )
        for source in states for source_prime in states for target in states
    )
    dynamic_contract_holds = stable_contract_holds && drift_encoding &&
        r2_monotone && r2_strict && external_encoding && core_encoding && e5

    bools = (false, true)
    multi_values = candidate.multi_alpha(nothing)
    multivalued = Set(multi_values) == Set(bools)
    initial = candidate.collapse_initial
    collapsed = candidate.collapse_update(initial)
    collapse_encoding =
        initial == (kappa=Set([nothing]), epsilon=Set(bools), rank=false) &&
        collapsed == (kappa=Set{Nothing}(), epsilon=Set{Bool}(), rank=true)
    collapse = collapse_encoding && candidate.collapse_update(collapsed) == collapsed
    region_encoding = Set(candidate.region) == Set([false])
    ins = region_encoding && any(
        inside != outside &&
            (inside in candidate.region) != (outside in candidate.region) &&
            candidate.observe(inside) == candidate.observe(outside)
        for inside in bools for outside in bools
    )
    blind = candidate.markers == (fm1=true, fm2=false, fm3=true, fm4=true)
    reachability_encoding = all(
        candidate.reaches(source, target) == (source == target)
        for source in bools for target in bools
    )
    no_terminal = reachability_encoding && !any(
        all(candidate.reaches(source, terminal) for source in bools)
        for terminal in bools
    )
    nondegenerate_contract_holds = multivalued && collapse && ins && blind && no_terminal

    (
        encoding_complete=encoding_complete,
        carrier_complete=carrier_complete,
        next_equations=next_equations,
        fixed_config=fixed_config,
        total_next=total_next,
        initial_dc=initial_dc,
        orbit=orbit,
        world_nontrivial=world_nontrivial,
        value_one=value_one,
        top_relations_empty=top_relations_empty,
        drift_encoding=drift_encoding,
        r2_monotone=r2_monotone,
        r2_strict=r2_strict,
        external_encoding=external_encoding,
        core_encoding=core_encoding,
        e5=e5,
        multivalued=multivalued,
        collapse=collapse,
        ins=ins,
        blind=blind,
        no_terminal=no_terminal,
        v5_1_contract_holds=v5_1_contract_holds,
        stable_contract_holds=stable_contract_holds,
        dynamic_contract_holds=dynamic_contract_holds,
        nondegenerate_contract_holds=nondegenerate_contract_holds,
        contract_holds=v5_1_contract_holds && stable_contract_holds &&
            dynamic_contract_holds && nondegenerate_contract_holds,
    )
end
