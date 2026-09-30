# RSB-GEN-001 golden reference: a verbatim copy of the measurement engine as of commit e1cf0ef
# (tools/ReactivationMeasurement/src/substrate.jl and measure.jl), before the three-layer split.
# The refactored engine must reproduce this engine's case records exactly. Do not edit the
# copied code below; it is the fixed reference, not maintained code.
module LegacyEngine
# ---- substrate.jl @ e1cf0ef ----
# Substrate and protocol (design-r2 §2). Sets of units are bit masks with unit index i at
# bit i (the profile's `unit_index_is_lsb_index`).

struct Substrate
    n::Int
    # (source, target, weight), 0-based; ordinary weights and the environment map together.
    # Both carry the same sent value, so silencing a source silences it on every edge.
    edges::Vector{NTuple{3,Int}}
    thresholds::Vector{Int}
    inputs::Int
    outputs::Int
    function Substrate(n, edges, thresholds, inputs, outputs)
        1 <= n <= 16 || throw(ArgumentError("unit count must be between 1 and 16"))
        length(thresholds) == n || throw(ArgumentError("one threshold per unit is required"))
        for (s, t, _) in edges
            (0 <= s < n && 0 <= t < n) || throw(ArgumentError("edge index out of range"))
        end
        full = (1 << n) - 1
        (inputs & ~full == 0 && outputs & ~full == 0) || throw(ArgumentError("unit mask out of range"))
        new(n, collect(NTuple{3,Int}, edges), collect(Int, thresholds), inputs, outputs)
    end
end

struct Protocol
    preparation_steps::Int
    kappa_points::Int
    horizon::Int
    effect_points::Int
    function Protocol(preparation_steps, kappa_points, horizon, effect_points)
        preparation_steps >= 0 || throw(ArgumentError("preparation_steps must be ≥ 0"))
        horizon >= 1 || throw(ArgumentError("horizon must be ≥ 1"))
        1 <= kappa_points <= preparation_steps + 1 || throw(ArgumentError("invalid kappa window"))
        1 <= effect_points <= horizon || throw(ArgumentError("effect window must lie after the branch"))
        new(preparation_steps, kappa_points, horizon, effect_points)
    end
end

_mask(indices) = foldl((m, i) -> m | (1 << i), indices; init=0)

"""Build the substrate and protocol from a profile validated under `rsb-profile-schema-v2`."""
function substrate_from_profile(profile::AbstractDict)
    s = profile["substrate"]
    o = profile["observation"]
    index = Dict(u => i - 1 for (i, u) in enumerate(s["units"]))
    edges = [(e[1], e[2], e[3]) for e in vcat(s["weights"], s["environment_map"])]
    sub = Substrate(s["unit_count"], edges, s["thresholds"],
        _mask(index[u] for u in s["input_units"]), _mask(index[u] for u in s["output_units"]))
    o["state_window_points"] == o["kappa_transitions"] + 1 ||
        throw(ArgumentError("state_window_points must equal kappa_transitions + 1"))
    proto = Protocol(o["preparation_steps"], o["state_window_points"],
        o["intervention_horizon_steps"], o["effect_window_points"])
    sub, proto
end

"""One synchronous update from the old state `x` with the sources in `silenced` sending 0.
Weights and thresholds are unchanged and silenced units still update their own state."""
function step(sub::Substrate, x::Integer, silenced::Integer)
    sent = Int(x) & ~Int(silenced)
    totals = zeros(Int, sub.n)
    for (s, t, w) in sub.edges
        if (sent >> s) & 1 == 1
            totals[t + 1] = Base.checked_add(totals[t + 1], w)
        end
    end
    next = 0
    for j in 1:sub.n
        totals[j] >= sub.thresholds[j] && (next |= 1 << (j - 1))
    end
    next
end
# ---- measure.jl @ e1cf0ef ----
# Observation for one initial configuration q (design-r2 §3–§6).

function _trace(sub::Substrate, initial::Integer, steps::Integer, silenced::Integer)
    states = Vector{Int}(undef, steps + 1)
    states[1] = Int(initial)
    for t in 1:steps
        states[t + 1] = step(sub, states[t], silenced)
    end
    states
end

"""Units on at every one of the last `points` states."""
function _persistent(states::Vector{Int}, points::Int)
    acc = -1
    for t in (length(states) - points + 1):length(states)
        acc &= states[t]
    end
    acc & typemax(Int)
end

"""Inclusion-minimal silencing sets that lose `target`, compared against every proper subset
(loss need not be monotone when weights may be negative)."""
function _minimal_loss_sets(loss::Vector{Int}, target::Int)
    bit = 1 << target
    found = Int[]
    for a in 0:(length(loss) - 1)
        loss[a + 1] & bit == 0 && continue
        minimal = true
        sub = (a - 1) & a
        while true
            if sub != a && loss[sub + 1] & bit != 0
                minimal = false
                break
            end
            sub == 0 && break
            sub = (sub - 1) & a
        end
        minimal && push!(found, a)
    end
    found
end

"""
    measure_case(sub, proto, q) -> Dict

All observations for initial configuration `q`. Relations are recorded for every unit;
restricting them to M = O and E = I is left to the reader (RSB-003).
"""
function measure_case(sub::Substrate, proto::Protocol, q::Integer)
    0 <= q < (1 << sub.n) || throw(ArgumentError("q out of range"))
    prep = _trace(sub, Int(q), proto.preparation_steps, 0)
    z = prep[end]
    kappa = _persistent(prep, proto.kappa_points)
    epsilon = z & sub.inputs
    nsets = 1 << sub.n
    final = Vector{Int}(undef, nsets)
    persistent = Vector{Int}(undef, nsets)
    for a in 0:(nsets - 1)
        branch = _trace(sub, z, proto.horizon, a)
        final[a + 1] = branch[end]
        persistent[a + 1] = _persistent(branch, proto.effect_points)
    end
    baseline_persistent = persistent[1]
    baseline_final = final[1]
    loss = [baseline_persistent & ~p for p in persistent]
    single(u) = (1 << u) + 1
    pi = [loss[single(u)] for u in 0:(sub.n - 1)]
    rho = [loss[single(u)] & sub.outputs for u in 0:(sub.n - 1)]
    alpha = [(baseline_final ⊻ final[single(u)]) & sub.inputs for u in 0:(sub.n - 1)]
    sigma = [(baseline_final ⊻ final[single(u)]) & sub.outputs for u in 0:(sub.n - 1)]
    loss_sets = [_minimal_loss_sets(loss, c) for c in 0:(sub.n - 1)]
    collective = 0
    for c in 0:(sub.n - 1)
        sets = loss_sets[c + 1]
        (!isempty(sets) && all(a -> count_ones(a) >= 2, sets)) && (collective |= 1 << c)
    end
    Dict{String,Any}(
        "q" => Int(q),
        "preparation_trace" => prep,
        "z" => z,
        "kappa" => kappa,
        "epsilon" => epsilon,
        "future_final" => final,
        "future_persistent" => persistent,
        "pi" => pi,
        "rho" => rho,
        "alpha" => alpha,
        "sigma" => sigma,
        "loss_sets" => loss_sets,
        "collective_only_loss" => collective,
    )
end
end # module LegacyEngine
