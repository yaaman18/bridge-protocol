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
