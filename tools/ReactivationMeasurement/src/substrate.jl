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
