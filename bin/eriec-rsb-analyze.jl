#!/usr/bin/env julia
# The registered analysis of a completed reactivation run (RSB-ANALYZE-001).
#   julia --project=tools/ReactivationERIEC bin/eriec-rsb-analyze.jl RUN_DIR PROFILE PLAN KNOWN_DIFFERENCES
using TOML
using ReactivationERIEC

try
    length(ARGS) == 4 ||
        throw(ArgumentError("Usage: eriec-rsb-analyze.jl RUN_DIR PROFILE PLAN KNOWN_DIFFERENCES"))
    run_dir, profile, plan, known = ARGS
    report = analyze_run(run_dir; profile_path=profile, plan_path=plan, known_differences_path=known)
    TOML.print(stdout, report; sorted=true)
catch err
    println(stderr, "RSB analysis failed: ", sprint(showerror, err))
    exit(1)
end
