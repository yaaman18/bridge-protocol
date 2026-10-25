"""
Prototype substrate and criteria of AGENCY-001: agency (L2) and structural self-production (L3).
An unratified experiment, independent of ERIEC and of the RSB engine. Nothing here certifies a
phenomenal claim, and "consciousness" is not used as a name.
"""
module AgencySubstrate

using SHA
using TOML

export Params, Substrate, Schedule, State, run_trajectory, step!, initial_state, nunits,
    load_templates, survives, structure_persists, choice, value_differentiated,
    value_tracking_units, value_needed, self_producing, self_repairing, evaluate

include("substrate.jl")
include("templates.jl")
include("criteria.jl")

end
