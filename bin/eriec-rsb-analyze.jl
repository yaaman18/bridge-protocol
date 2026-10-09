#!/usr/bin/env julia
# The registered analysis of a completed reactivation run (RSB-ANALYZE-001).
#   julia --project=tools/ReactivationERIEC bin/eriec-rsb-analyze.jl RUN_DIR PROFILE PLAN
# PROFILE and PLAN may be relative to the current directory (the repository root); the known-difference
# registry is the one the plan names, checked against the plan's known_differences_sha256.
using TOML
using ReactivationERIEC

try
    length(ARGS) == 3 ||
        throw(ArgumentError("Usage: eriec-rsb-analyze.jl RUN_DIR PROFILE PLAN"))
    run_dir, profile, plan = ARGS
    report = analyze_run(run_dir; repo=pwd(), profile_path=profile, plan_path=plan)
    TOML.print(stdout, report; sorted=true)
catch err
    println(stderr, "RSB analysis failed: ", sprint(showerror, err))
    exit(1)
end
