"""
RSB-002: measurement engine for the reactivation substrate (design-r2 §2–§6).

Computes the preparation trace, the branch snapshot, κ and ε, every source-silencing
branch, future persistence and the observed relations for one initial configuration.
It does not evaluate DC, build an `ERIEState`, or compute the boundary; that is RSB-003,
which reads the case records written here. It must not depend on ERIEC.
"""
module ReactivationMeasurement

using SHA
using TOML
using SubstrateRegistry

export Substrate, Protocol, substrate_from_profile, measure_case,
    CASE_RECORD_FORMAT, CASE_RECORD_FIELDS, validate_case_record, start_run

include("substrate.jl")
include("measure.jl")
include("records.jl")
include("run.jl")

end
