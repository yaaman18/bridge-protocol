# Layer 1: the system under measurement (RSB-GEN-001 §2).
#
# A system is a finite deterministic map on bit-mask states. Unit i is bit i of a state and of
# a silencing mask. The measurement layers above only call `nunits` and `step`; they never read
# a system's parameters (weights, thresholds, rules).
#
# Intervention is SOURCE SILENCING ONLY (RSB-GEN-001 §3, user decision 2026-09-28).
# A silenced unit sends 0 on every influence it has on OTHER units, and still updates its own
# state as usual (it is not forced to 0). Value forcing, edge-level cuts and stochastic
# interventions are deliberately not supported yet. To add them later, introduce an
# `AbstractIntervention`, move silencing to one implementation of it, and re-check that the
# response tables of registered profiles keep their meaning.

"""Supertype of systems the measurement engine can observe."""
abstract type AbstractSystem end

"""
    nunits(sys) -> Int

Number of units. Unit i (0-based) is bit i of every state and silencing mask.
"""
function nunits end

"""
    step(sys, x, silenced) -> Int

One update from state `x` while the units in `silenced` send 0. Must be a pure function of its
arguments: no randomness, no global or hidden state. Checked by `check_system_conformance`.
"""
function step end

"""The largest unit count a bit-mask state can carry."""
const MAX_UNITS = 62

_full_mask(n::Integer) = (1 << n) - 1

"""
    check_system_conformance(sys; states=..., silencings=...) -> true

Checks the contract every system must meet (RSB-GEN-001 §7), throwing `ArgumentError` on the
first violation:

- range: `step` returns a state inside the unit mask;
- determinism: the same arguments give the same result, also after other calls in between
  (no hidden state);
- silencing: a silenced unit influences no other unit. Flipping the state of a silenced unit
  `u` may change bit `u` of the result and no other bit.

Whether a silenced unit is "not forced to 0" depends on the dynamics and is checked by each
system's own tests.
"""
function check_system_conformance(sys::AbstractSystem;
        states=nothing, silencings=nothing)
    n = nunits(sys)
    1 <= n <= MAX_UNITS || throw(ArgumentError("nunits must be between 1 and $MAX_UNITS"))
    full = _full_mask(n)
    xs = states === nothing ? (n <= 8 ? collect(0:full) : error("pass `states` for n > 8")) : collect(states)
    ss = silencings === nothing ? (n <= 8 ? collect(0:full) : error("pass `silencings` for n > 8")) : collect(silencings)
    for x in xs, s in ss
        y = step(sys, x, s)
        (y isa Integer && 0 <= y <= full) ||
            throw(ArgumentError("step left the unit mask at x=$x, silenced=$s"))
        step(sys, full & ~x, full & ~s)          # an unrelated call in between
        step(sys, x, s) == y ||
            throw(ArgumentError("step is not deterministic at x=$x, silenced=$s"))
        for u in 0:(n - 1)
            (s >> u) & 1 == 1 || continue
            y2 = step(sys, x ⊻ (1 << u), s)
            (y ⊻ y2) & ~(1 << u) == 0 ||
                throw(ArgumentError("silenced unit $u influenced another unit at x=$x, silenced=$s"))
        end
    end
    true
end
