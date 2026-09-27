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
