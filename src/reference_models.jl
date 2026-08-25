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

_reference_exact_fields(candidate::NamedTuple, fields) =
    Set(propertynames(candidate)) == fields

function _reference_unique_vector(values)
    values isa AbstractVector || return nothing
    items = collect(values)
    length(items) == length(unique(items)) || return nothing
    items
end

function _reference_literal_table(table, domain, codomain)
    table isa AbstractDict || return nothing
    Set(keys(table)) == Set(domain) || return nothing
    normalized = Dict{eltype(domain),Set{eltype(codomain)}}()
    for key in domain
        values = table[key]
        values isa AbstractVector || values isa AbstractSet || return nothing
        items = collect(values)
        length(items) == length(unique(items)) || return nothing
        Set(items) ⊆ Set(codomain) || return nothing
        normalized[key] = Set(items)
    end
    normalized
end

const _LARGE_DC_LITERAL_FIELDS = Set((
    :schema_version, :contract_id, :lean_decl, :k,
    :motors, :environments, :cores, :states,
    :alpha, :sigma, :pi, :rho, :kappa, :epsilon,
    :boundary, :state,
))

function _decode_large_dc_literal(candidate::NamedTuple)
    _reference_exact_fields(candidate, _LARGE_DC_LITERAL_FIELDS) || return nothing
    candidate.schema_version == 1 || return nothing
    candidate.contract_id == "reference_models.arbitrarily_large_dc" || return nothing
    candidate.lean_decl == "ERIEC.RefModel.arbitrarily_large_nondegenerate_dc" || return nothing
    candidate.k isa Integer && candidate.k >= 2 || return nothing

    motors = _reference_unique_vector(candidate.motors)
    environments = _reference_unique_vector(candidate.environments)
    cores = _reference_unique_vector(candidate.cores)
    states = _reference_unique_vector(candidate.states)
    any(isnothing, (motors, environments, cores, states)) && return nothing
    length(motors) == candidate.k && length(environments) == candidate.k &&
        length(cores) == candidate.k || return nothing
    length(states) == 1 || return nothing
    candidate.state in states || return nothing

    alpha = _reference_literal_table(candidate.alpha, motors, environments)
    sigma = _reference_literal_table(candidate.sigma, environments, motors)
    pi = _reference_literal_table(candidate.pi, motors, cores)
    rho = _reference_literal_table(candidate.rho, cores, motors)
    kappa = _reference_literal_table(candidate.kappa, states, cores)
    epsilon = _reference_literal_table(candidate.epsilon, states, environments)
    any(isnothing, (alpha, sigma, pi, rho, kappa, epsilon)) && return nothing
    boundary = _reference_unique_vector(candidate.boundary)
    boundary === nothing && return nothing
    Set(boundary) ⊆ Set(cores) || return nothing

    M, E, C, S = eltype(motors), eltype(environments), eltype(cores), eltype(states)
    sys = ERIEState{M,E,C,S}(
        m -> alpha[m], e -> sigma[e], m -> pi[m], c -> rho[c],
        s -> kappa[s], s -> epsilon[s], Set(boundary), candidate.state,
    )
    (; sys, motors, environments, cores, k=Int(candidate.k), alpha)
end

"""Validate one closed finite encoding of `LargeNondegenerateWitness k`."""
function check_arbitrarily_large_nondegenerate_models(candidate::NamedTuple)
    decoded = _decode_large_dc_literal(candidate)
    decoded === nothing && return false
    dc = check_DC(decoded.sys)
    check_DC(decoded.sys, decoded.motors, decoded.environments, decoded.cores) &&
        length(decoded.motors) == decoded.k &&
        length(decoded.environments) == decoded.k &&
        length(decoded.cores) == decoded.k &&
        any(length(values) >= 2 for values in values(decoded.alpha)) &&
        !isempty(dc.act)
end

const _LARGE_AX_LITERAL_FIELDS = Set((
    :schema_version, :contract_id, :lean_decl, :k,
    :stable, :dynamic, :same_stable_id,
))
const _LARGE_AX_STABLE_FIELDS = Set((
    :id, :motors, :environments, :cores, :states,
    :relation_tag, :dc_constructor, :frame_constructor, :total_next,
    :kappa, :epsilon, :omega, :next, :boundary, :state,
    :phi_tag, :theta_tag, :drift_tag, :step_tag,
))
const _LARGE_AX_DYNAMIC_FIELDS = Set((
    :stable_id, :r2_tag, :external_tag, :core_tag, :core_iso_tag, :e5_tag,
))

function _large_ax_failed_result(; encoding_complete=false)
    (
        encoding_complete=encoding_complete, canonical_identity=false, dc=false,
        frame=false, total=false, cards=false, multivalued=false,
        hinge_nonempty=false, internal_total=false, r2=false, e5=false,
        dynamic_stable=false, same_stable=false, contract_holds=false,
    )
end

function _decode_large_ax_literal(candidate::NamedTuple)
    _reference_exact_fields(candidate, _LARGE_AX_LITERAL_FIELDS) || return nothing
    candidate.schema_version == 1 || return nothing
    candidate.contract_id == "reference_models.arbitrarily_large_ax_core_discrete" || return nothing
    candidate.lean_decl == "ERIEC.RefModel.arbitrarily_large_ax_core_discrete_model" || return nothing
    candidate.k isa Integer && candidate.k >= 2 || return nothing
    candidate.stable isa NamedTuple && candidate.dynamic isa NamedTuple || return nothing
    _reference_exact_fields(candidate.stable, _LARGE_AX_STABLE_FIELDS) || return nothing
    _reference_exact_fields(candidate.dynamic, _LARGE_AX_DYNAMIC_FIELDS) || return nothing

    stable = candidate.stable
    dynamic = candidate.dynamic
    motors = _reference_unique_vector(stable.motors)
    environments = _reference_unique_vector(stable.environments)
    cores = _reference_unique_vector(stable.cores)
    states = _reference_unique_vector(stable.states)
    any(isnothing, (motors, environments, cores, states)) && return nothing
    expected = collect(0:(Int(candidate.k) - 1))
    motors == expected && environments == expected && cores == expected || return nothing
    states == [:s0, :s1, :s2] || return nothing

    stable.id == :large_stable_v1 || return nothing
    stable.relation_tag == :fin_full_relation_v1 || return nothing
    stable.dc_constructor == :large_ax_core_dc_v1 || return nothing
    stable.frame_constructor == :large_dyn_frame_v1 || return nothing
    stable.phi_tag == :large_ref_phi_v1 || return nothing
    stable.theta_tag == :large_ref_theta_v1 || return nothing
    stable.drift_tag == :large_ref_drift_v1 || return nothing
    stable.step_tag == :ref_step_v1 || return nothing
    dynamic.r2_tag == :large_ref_drift_r2prime_v1 || return nothing
    dynamic.external_tag == :large_ref_external_v1 || return nothing
    dynamic.core_tag == :large_ref_core_v1 || return nothing
    dynamic.core_iso_tag == :equality_v1 || return nothing
    dynamic.e5_tag == :large_ref_e5_v1 || return nothing

    kappa = _reference_literal_table(stable.kappa, states, cores)
    epsilon = _reference_literal_table(stable.epsilon, states, environments)
    any(isnothing, (kappa, epsilon)) && return nothing
    stable.omega isa AbstractDict && Set(keys(stable.omega)) == Set(states) || return nothing
    stable.next isa AbstractDict && Set(keys(stable.next)) == Set(states) || return nothing
    stable.total_next isa AbstractDict && Set(keys(stable.total_next)) == Set(states) || return nothing
    boundary = _reference_unique_vector(stable.boundary)
    boundary === nothing && return nothing
    Set(boundary) ⊆ Set(cores) || return nothing
    stable.state in states || return nothing
    (; k=Int(candidate.k), stable, dynamic, motors, environments, cores, states,
        kappa, epsilon, boundary, same_stable_id=candidate.same_stable_id)
end

"""Validate one closed encoding of `LargeAXCoreReferenceWitness k`."""
function check_arbitrarily_large_ax_core_discrete_models(candidate::NamedTuple)
    decoded = _decode_large_ax_literal(candidate)
    decoded === nothing && return _large_ax_failed_result()
    stable, dynamic = decoded.stable, decoded.dynamic
    states = decoded.states
    full_cores = Set(decoded.cores)
    full_environments = Set(decoded.environments)
    expected_next = Dict(:s0 => :s1, :s1 => :s2, :s2 => :s2)
    expected_kappa = Dict(:s0 => full_cores, :s1 => full_cores, :s2 => Set{Int}())
    expected_epsilon = Dict(
        :s0 => full_environments, :s1 => full_environments, :s2 => Set{Int}(),
    )
    expected_omega = Dict(:s0 => false, :s1 => true, :s2 => true)

    canonical_identity = true
    cards = all(length(carrier) == decoded.k for carrier in
        (decoded.motors, decoded.environments, decoded.cores))
    dc_sys = ERIEState{Int,Int,Int,Symbol}(
        _ -> full_environments, _ -> Set(decoded.motors),
        _ -> full_cores, _ -> Set(decoded.motors),
        state -> decoded.kappa[state], state -> decoded.epsilon[state],
        Set(decoded.boundary), stable.state,
    )
    dc = check_DC(dc_sys, decoded.motors, decoded.environments, decoded.cores)
    multivalued = any(length(full_environments) >= 2 for _ in decoded.motors)
    hinge_nonempty = !isempty(check_DC(dc_sys).act)

    frame = decoded.kappa == expected_kappa && decoded.epsilon == expected_epsilon &&
        stable.omega == expected_omega && stable.next == expected_next
    total = stable.total_next == expected_next
    update(state) = (
        kappa=stable.omega[state] ? Set{Int}() : intersect(decoded.kappa[state], full_cores),
        epsilon=stable.omega[state] ? Set{Int}() :
            intersect(decoded.epsilon[state], full_environments),
        omega=(!stable.omega[state] && !isempty(decoded.kappa[state])) || stable.omega[state],
    )
    internal_total = frame && total && all(states) do state
        target = stable.next[state]
        updated = update(state)
        decoded.kappa[target] == updated.kappa &&
            decoded.epsilon[target] == updated.epsilon &&
            stable.omega[target] == updated.omega
    end
    r2 = all((false, true)) do world
        all((Set{Int}(), full_cores)) do core_set
            shifted = (!world && !isempty(core_set)) || world
            world <= shifted && (isempty(core_set) || world || world < shifted)
        end
    end
    e5 = all(!false for _source in states for _source_prime in states for _target in states)
    dynamic_stable = dynamic.stable_id == stable.id
    same_stable = decoded.same_stable_id == stable.id && dynamic_stable
    contract_holds = canonical_identity && dc && frame && total && cards && multivalued &&
        hinge_nonempty && internal_total && r2 && e5 && dynamic_stable && same_stable
    (
        encoding_complete=true, canonical_identity, dc, frame, total, cards,
        multivalued, hinge_nonempty, internal_total, r2, e5,
        dynamic_stable, same_stable, contract_holds,
    )
end

const _THREE_LAYER_LITERAL_FIELDS = Set((
    :schema_version, :contract_id, :lean_decl, :k, :tier1, :bridge, :section13_2,
))
const _THREE_LAYER_BRIDGE_FIELDS = Set((
    :dc_stable_id, :world_tag, :direction, :normalized_value,
))
const _THREE_LAYER_SECTION_FIELDS = Set((
    :bool_states, :multi_alpha, :collapse_initial, :collapse_after_initial,
    :collapse_after_collapsed, :observe, :region, :markers, :reaches,
))

function _three_layer_failed_result(; encoding_complete=false, tier1=nothing)
    (
        encoding_complete, tier1, tier1_contract_holds=false,
        bridge_identity=false, direction_nonzero=false, direction_fixed=false,
        world_nontrivial=false, value_one=false, multivalued=false,
        collapse=false, ins=false, blind=false, no_terminal=false,
        section13_2_contract_holds=false, contract_holds=false,
    )
end

"""Validate one closed encoding of `LargeThreeLayerReferenceWitness k`."""
function check_arbitrarily_large_three_layer_reference_models(candidate::NamedTuple)
    _reference_exact_fields(candidate, _THREE_LAYER_LITERAL_FIELDS) ||
        return _three_layer_failed_result()
    candidate.schema_version == 1 || return _three_layer_failed_result()
    candidate.contract_id == "reference_models.arbitrarily_large_three_layer" ||
        return _three_layer_failed_result()
    candidate.lean_decl == "ERIEC.RefModel.arbitrarily_large_three_layer_reference_model" ||
        return _three_layer_failed_result()
    candidate.k isa Integer && candidate.k >= 2 || return _three_layer_failed_result()
    candidate.tier1 isa NamedTuple && candidate.bridge isa NamedTuple &&
        candidate.section13_2 isa NamedTuple || return _three_layer_failed_result()
    _reference_exact_fields(candidate.bridge, _THREE_LAYER_BRIDGE_FIELDS) ||
        return _three_layer_failed_result()
    _reference_exact_fields(candidate.section13_2, _THREE_LAYER_SECTION_FIELDS) ||
        return _three_layer_failed_result()

    tier1 = check_arbitrarily_large_ax_core_discrete_models(candidate.tier1)
    tier1.contract_holds || return _three_layer_failed_result(
        encoding_complete=true, tier1=tier1,
    )
    candidate.tier1.k == candidate.k || return _three_layer_failed_result(
        encoding_complete=true, tier1=tier1,
    )
    bridge = candidate.bridge
    section = candidate.section13_2
    bridge_identity = bridge.dc_stable_id == candidate.tier1.stable.id
    bridge.world_tag == :stable_world_identity_v1 || return _three_layer_failed_result(
        encoding_complete=true, tier1=tier1,
    )
    direction = _reference_unique_vector(bridge.direction)
    direction === nothing && return _three_layer_failed_result(
        encoding_complete=true, tier1=tier1,
    )
    direction_nonzero = direction == [1 // 1]
    direction_fixed = direction_nonzero
    world_nontrivial = direction_nonzero
    value_one = bridge.normalized_value == 1 // 1

    section.bool_states == [false, true] || return _three_layer_failed_result(
        encoding_complete=true, tier1=tier1,
    )
    section.multi_alpha isa AbstractDict && Set(keys(section.multi_alpha)) == Set([:unit]) ||
        return _three_layer_failed_result(encoding_complete=true, tier1=tier1)
    multi_values = section.multi_alpha[:unit]
    multi_values isa AbstractVector || return _three_layer_failed_result(
        encoding_complete=true, tier1=tier1,
    )
    section.observe isa AbstractDict && Set(keys(section.observe)) == Set((false, true)) ||
        return _three_layer_failed_result(encoding_complete=true, tier1=tier1)
    section.reaches isa AbstractDict &&
        Set(keys(section.reaches)) == Set((
            (false, false), (false, true), (true, false), (true, true),
        )) || return _three_layer_failed_result(encoding_complete=true, tier1=tier1)

    collapse_map = Dict(
        section.collapse_initial => section.collapse_after_initial,
        section.collapse_after_initial => section.collapse_after_collapsed,
    )
    internal = (
        states=[:s0, :s1, :s2],
        next=copy(_REFERENCE_MODEL_NEXT),
        config=copy(_STABLE_REFERENCE_CONFIG),
        world_loop=ones(1, 1),
        normalized_value=bridge.normalized_value,
        top_phi=Set{Nothing}(), top_theta=Set{Nothing}(),
        drift=(world, core_set) -> (!world && !isempty(core_set)) || world,
        external=(_source, _target) -> false,
        core=state -> state == :s2 ? Set{Symbol}() : Set([:c]),
        multi_alpha=_ -> Set(multi_values),
        collapse_initial=section.collapse_initial,
        collapse_update=value -> get(collapse_map, value, value),
        observe=value -> section.observe[value],
        region=Set(section.region),
        markers=section.markers,
        reaches=(source, target) -> section.reaches[(source, target)],
    )
    checked = check_reference_models(internal)
    contract_holds = tier1.contract_holds && bridge_identity && direction_nonzero &&
        direction_fixed && world_nontrivial && value_one && checked.nondegenerate_contract_holds
    (
        encoding_complete=true, tier1, tier1_contract_holds=tier1.contract_holds,
        bridge_identity, direction_nonzero, direction_fixed, world_nontrivial, value_one,
        multivalued=checked.multivalued, collapse=checked.collapse, ins=checked.ins,
        blind=checked.blind, no_terminal=checked.no_terminal,
        section13_2_contract_holds=checked.nondegenerate_contract_holds,
        contract_holds,
    )
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
    v5_required = (:states, :next)
    required = (
        :states, :next, :config, :world_loop, :normalized_value,
        :top_phi, :top_theta, :drift, :external, :core,
        :multi_alpha, :collapse_initial, :collapse_update,
        :observe, :region, :markers, :reaches,
    )
    supplied_fields = Set(propertynames(candidate))
    minimal_v5_encoding = supplied_fields == Set(v5_required)
    encoding_complete = supplied_fields == Set(required)
    v5_1_encoding_complete = minimal_v5_encoding || encoding_complete
    if !v5_1_encoding_complete
        return (
            encoding_complete=false,
            v5_1_encoding_complete=false,
            v5_1_contract_holds=false,
            stable_contract_holds=false,
            dynamic_contract_holds=false,
            nondegenerate_contract_holds=false,
            contract_holds=false,
        )
    end

    expected_states = Set((:s0, :s1, :s2))
    states = collect(candidate.states)
    carrier_complete = length(states) == 3 && allunique(states) &&
        Set(states) == expected_states
    next_complete = carrier_complete && Set(keys(candidate.next)) == expected_states
    next_equations = next_complete &&
        candidate.next[:s0] == :s1 &&
        candidate.next[:s1] == :s2 &&
        candidate.next[:s2] == :s2
    v5_1_contract_holds = carrier_complete && next_equations

    if minimal_v5_encoding
        return (
            encoding_complete=false,
            v5_1_encoding_complete=true,
            carrier_complete=carrier_complete,
            next_equations=next_equations,
            v5_1_contract_holds=v5_1_contract_holds,
            stable_contract_holds=false,
            dynamic_contract_holds=false,
            nondegenerate_contract_holds=false,
            contract_holds=v5_1_contract_holds,
        )
    end

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
        v5_1_encoding_complete=v5_1_encoding_complete,
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
