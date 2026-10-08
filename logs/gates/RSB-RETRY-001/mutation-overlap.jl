using ReactivationMeasurement
const _M = "overlap"
if _M == "overlap"
    # comparison removed (same signature as the original, so it replaces it)
    @eval ReactivationMeasurement retry_mismatches(a::AbstractString, b::AbstractString, c::AbstractString) = String[]
else
    # attempt limit and retry condition removed
    @eval ReactivationMeasurement function _attempt(token, abs_out::AbstractString, run_id::String)
        prior = _prior_attempts(token, dirname(abs_out))
        number = isempty(prior) ? 1 : 2
        (; number, previous_dir=isempty(prior) ? "" : last(prior).dir,
           previous_run_id=isempty(prior) ? "" : last(prior).run_id)
    end
end
println("mutant active: ", _M)
include("/Users/yamaguchimitsuyuki/bridge-protocol/tools/ReactivationMeasurement/test/runtests.jl")
