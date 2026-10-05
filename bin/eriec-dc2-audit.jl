#!/usr/bin/env julia
using TOML
include(joinpath(@__DIR__, "..", "tools", "DC2Audit.jl"))

try
    if ARGS == ["ground-truth"] || ARGS == ["ground-truth", "--v2"]
        TOML.print(stdout, ModelAudit.ground_truth_report(length(ARGS) == 2 ? 2 : 1); sorted=true)
    elseif ARGS == ["known-differences"]
        TOML.print(stdout, ModelAudit.known_difference_report(); sorted=true)
    elseif ARGS in (["report"], ["report", "--no-measured-search"])
        TOML.print(stdout, DC2Audit.dc2_audit_report(measured_search=length(ARGS) == 1); sorted=true)
    else
        throw(ArgumentError("Usage: eriec-dc2-audit.jl report [--no-measured-search] | ground-truth [--v2] | known-differences"))
    end
catch err
    println(stderr, "DC2 audit failed: ", sprint(showerror, err))
    exit(1)
end
