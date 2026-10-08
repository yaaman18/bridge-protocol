#!/usr/bin/env julia
# Read-only pre-registration check of an analysis plan v2 against the criterion package (RSB-ANALYZE-001).
#   julia --project=tools/ReactivationERIEC bin/eriec-rsb-preflight.jl PLAN PROFILE
using ReactivationERIEC

length(ARGS) == 2 || (println(stderr, "Usage: eriec-rsb-preflight.jl PLAN PROFILE"); exit(2))
r = preflight(pwd(); plan_path=ARGS[1], profile_path=ARGS[2])
println(r["ok"] ? "PREFLIGHT OK" : "PREFLIGHT FAILED")
foreach(p -> println(" - ", p), r["problems"])
exit(r["ok"] ? 0 : 1)
