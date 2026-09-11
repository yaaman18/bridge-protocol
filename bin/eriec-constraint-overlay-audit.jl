#!/usr/bin/env julia
using TOML
include(joinpath(@__DIR__, "..", "tools", "ConstraintOverlayAudit.jl"))

try
    ARGS == ["overlay"] ||
        throw(ArgumentError("Usage: eriec-constraint-overlay-audit.jl overlay"))
    TOML.print(stdout, ConstraintOverlayAudit.constraint_overlay_report(); sorted=true)
catch err
    println(stderr, "Constraint overlay audit failed: ", sprint(showerror, err))
    exit(1)
end
