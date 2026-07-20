"""Finite executable trace used by the TemporalDC boundary checkers.

`dc_holds[i]` is read-only certification evidence at occurrence `i`.  The
runtime representation is a linear prefix; Lean owns claims about arbitrary
generated reachability and infinite futures.
"""
struct TemporalDCTrace
    dc_holds::Vector{Bool}
end

TemporalDCTrace(dc_holds::AbstractVector{Bool}) = TemporalDCTrace(collect(dc_holds))

function _temporal_dc_bits(trace)
    bits = trace isa TemporalDCTrace ? trace.dc_holds :
        trace isa AbstractVector{Bool} ? trace :
        hasproperty(trace, :dc_holds) ? getproperty(trace, :dc_holds) :
        throw(ArgumentError("trace must provide a Bool dc_holds vector"))
    all(value -> value isa Bool, bits) ||
        throw(ArgumentError("dc_holds must contain only Bool values"))
    collect(Bool, bits)
end

function _termination_sources(bits::AbstractVector{Bool})
    findall(index -> bits[index] && !bits[index + 1], 1:(length(bits) - 1))
end

"""Check observed functional termination on a finite linear trace.

A DC-loss transition is reported only when both endpoints are observed.
Missing observations never count as evidence for either retention or loss.
"""
function check_observed_termination(trace, obs_mask::AbstractVector{Bool})
    bits = _temporal_dc_bits(trace)
    length(obs_mask) == length(bits) || return false
    any(index -> obs_mask[index] && obs_mask[index + 1], _termination_sources(bits))
end

"""Refute recovery within a finite horizon after a DC-loss transition.

This checker can find a recovery counterexample in the inspected prefix; it
cannot certify the Lean `∀`-future permanence claim.
"""
function check_permanent_termination_prefix(trace, horizon::Integer)
    horizon >= 0 || throw(ArgumentError("horizon must be nonnegative"))
    bits = _temporal_dc_bits(trace)
    for source in _termination_sources(bits)
        target = source + 1
        stop = min(length(bits), target + horizon)
        all(!, @view(bits[target:stop])) && return true
    end
    false
end

"""Audit the canonical finite collapse prefix used by VP-TMP-003."""
function check_collapse_trace_termination(N::Integer)
    N >= 1 || throw(ArgumentError("N must be at least one"))
    trace = TemporalDCTrace(vcat(true, falses(N)))
    trace.dc_holds[1] &&
        check_permanent_termination_prefix(trace, N - 1)
end

"""Check finite-prefix precariousness for a linear certification trace."""
function check_precarious_prefix(trace)
    bits = _temporal_dc_bits(trace)
    sources = _termination_sources(bits)
    all(index -> !bits[index] || any(source -> index <= source, sources), eachindex(bits))
end

"""Check the finite part of no-internal-escape on a linear trace.

As with `check_permanent_termination_prefix`, this audits only the supplied
prefix and does not turn finite non-recovery into an infinite certificate.
"""
function check_no_escape_prefix(trace)
    bits = _temporal_dc_bits(trace)
    sources = filter(source -> all(!, @view(bits[(source + 1):end])),
        _termination_sources(bits))
    all(index -> !bits[index] || any(source -> index <= source, sources), eachindex(bits))
end
