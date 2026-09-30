# Layer 2: the response of a system to source silencing (RSB-GEN-001 §2, design-r2 §3–§6).
#
# Nothing here knows about roles, relations or any criterion. A response table records, for
# one initial configuration, the preparation trace, the branch point, and the final state and
# the future-persistent set after silencing each measured set of units.

function _trace(sys::AbstractSystem, initial::Integer, steps::Integer, silenced::Integer)
    states = Vector{Int}(undef, steps + 1)
    states[1] = Int(initial)
    for t in 1:steps
        states[t + 1] = step(sys, states[t], silenced)
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
(loss need not be monotone when weights may be negative). `loss` is indexed by mask + 1 over
every silencing set."""
function _minimal_loss_sets(loss::Vector{Int}, target::Int)
    _minimal_sets(a -> loss[a + 1], 0:(length(loss) - 1), target)
end

# Shared by the exhaustive and the order-limited forms. `loss_of(a)` must be defined for every
# proper subset of every set in `sets`, which holds when `sets` is downward closed.
function _minimal_sets(loss_of, sets, target::Int)
    bit = 1 << target
    found = Int[]
    for a in sets
        loss_of(a) & bit == 0 && continue
        minimal = true
        sub = (a - 1) & a
        while true
            if sub != a && loss_of(sub) & bit != 0
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

"""Refuse measurements that would need more branches than this (about 4 million)."""
const MAX_BRANCHES = 1 << 22

"""
    silencing_sets(n, k) -> Vector{Int}

Every set of at most `k` units, as masks in increasing order. `k = n` gives all `2^n` sets.
The family is downward closed: every subset of a listed set is listed.
"""
function silencing_sets(n::Integer, k::Integer)
    1 <= n <= MAX_UNITS || throw(ArgumentError("n must be between 1 and $MAX_UNITS"))
    1 <= k <= n || throw(ArgumentError("max_silencing_order must be between 1 and n"))
    total = sum(binomial(big(n), r) for r in 0:k)
    total <= MAX_BRANCHES ||
        throw(ArgumentError("$total silencing sets exceed the limit of $MAX_BRANCHES; lower max_silencing_order"))
    k == n && return collect(0:_full_mask(n))
    sets = Int[0]
    function extend(mask, next_unit, size)
        size == k && return
        for u in next_unit:(n - 1)
            m = mask | (1 << u)
            push!(sets, m)
            extend(m, u + 1, size + 1)
        end
    end
    extend(0, 0, 0)
    sort!(sets)
end

"""
The response of a system for one initial configuration `q`.

`silencing_sets`, `final` and `persistent` are aligned. The table holds no reference to the
system, so anything that reads it cannot read the system's parameters (RSB-GEN-001 §6).
"""
struct ResponseTable
    n::Int
    q::Int
    preparation_trace::Vector{Int}
    z::Int
    prefix_persistent::Int
    max_silencing_order::Int
    silencing_sets::Vector{Int}
    final::Vector{Int}
    persistent::Vector{Int}
end

"""
    measure_response(sys, proto, q; max_silencing_order = nunits(sys)) -> ResponseTable

Runs the natural preparation from `q`, takes its last state as the branch point `z`, and for
every set of at most `max_silencing_order` units runs the silenced branch from `z`. The
exhaustive default reproduces the RSB-002 observation exactly.
"""
function measure_response(sys::AbstractSystem, proto::Protocol, q::Integer;
        max_silencing_order::Integer=nunits(sys))
    n = nunits(sys)
    0 <= q <= _full_mask(n) || throw(ArgumentError("q out of range"))
    sets = silencing_sets(n, max_silencing_order)
    prep = _trace(sys, Int(q), proto.preparation_steps, 0)
    z = prep[end]
    final = Vector{Int}(undef, length(sets))
    persistent = Vector{Int}(undef, length(sets))
    for (i, a) in enumerate(sets)
        branch = _trace(sys, z, proto.horizon, a)
        final[i] = branch[end]
        persistent[i] = _persistent(branch, proto.effect_points)
    end
    ResponseTable(n, Int(q), prep, z, _persistent(prep, proto.kappa_points),
        Int(max_silencing_order), sets, final, persistent)
end

is_exhaustive(t::ResponseTable) = t.max_silencing_order == t.n

"""Units lost relative to the unsilenced branch, aligned with `t.silencing_sets`."""
losses(t::ResponseTable) = [t.persistent[1] & ~p for p in t.persistent]

"""Index of the silencing set `mask` in the table; `nothing` if it was not measured."""
function set_index(t::ResponseTable, mask::Integer)
    is_exhaustive(t) && return 0 <= mask <= _full_mask(t.n) ? Int(mask) + 1 : nothing
    r = searchsorted(t.silencing_sets, Int(mask))
    isempty(r) ? nothing : first(r)
end

"""
    minimal_loss_sets(t, target) -> Vector{Int}

The inclusion-minimal silencing sets that lose `target`, among the measured sets. Because the
measured family is downward closed, every set returned is minimal among ALL sets. What an
order-limited table cannot show is a minimal set larger than `t.max_silencing_order`.
"""
function minimal_loss_sets(t::ResponseTable, target::Integer)
    loss = losses(t)
    _minimal_sets(a -> loss[set_index(t, a)], t.silencing_sets, Int(target))
end

"""Units lost under some measured silencing set but under no single-unit silencing."""
function collective_only_loss(t::ResponseTable)
    acc = 0
    for c in 0:(t.n - 1)
        sets = minimal_loss_sets(t, c)
        (!isempty(sets) && all(a -> count_ones(a) >= 2, sets)) && (acc |= 1 << c)
    end
    acc
end
