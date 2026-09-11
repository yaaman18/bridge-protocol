#!/usr/bin/env julia
using TOML
include(joinpath(@__DIR__, "..", "tools", "AssumptionSuiteAudit.jl"))

try
    ARGS == ["suites"] ||
        throw(ArgumentError("Usage: eriec-assumption-suite-audit.jl suites"))
    TOML.print(stdout, AssumptionSuiteAudit.assumption_suite_report(); sorted=true)
catch err
    println(stderr, "Assumption suite audit failed: ", sprint(showerror, err))
    exit(1)
end
