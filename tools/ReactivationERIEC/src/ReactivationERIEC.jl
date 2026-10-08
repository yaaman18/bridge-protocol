"""
DC and DC2 criteria for the reactivation measurement engine (RSB-003).

The engine (`ReactivationMeasurement`) does not depend on ERIEC; this package depends on both and
holds every line of code that decides DC or DC2 on a case record, so that RSB-PLAN-002 §3 can bind
the criteria by this directory's tree. DC is ERIEC's `check_DC`; DC2 is the unratified experiment
of formal-experiments/M1Refinement.lean (hUnit = MutualPair, specs/packets/DC2-HUNIT-N3.md).
Nothing here certifies a phenomenal claim.
"""
module ReactivationERIEC

using ERIEC
using ReactivationMeasurement
using SubstrateRegistry
import SHA
const RM = ReactivationMeasurement

export DCCriterion, DC2Criterion, erie_model, graph_boundary,
    DC_VALUE_KEYS, DC_DIAGNOSTIC_KEYS, DC2_VALUE_KEYS, DC2_DIAGNOSTIC_KEYS,
    analyze_run, v4_pairs, preflight

include("dc2_core.jl")
include("reading.jl")
include("dc.jl")
include("dc2.jl")
include("analysis.jl")
include("preflight.jl")

end
