#!/usr/bin/env julia
using TOML
include(joinpath(@__DIR__,"..","tools","BackgroundAudit.jl"))
try
    if ARGS == ["examples"]
        TOML.print(stdout,BackgroundAudit.background_audit_report(); sorted=true)
    elseif ARGS == ["measured-witnesses"]
        report = BackgroundAudit.adjoint_measured_witness_report()
        TOML.print(stdout,report; sorted=true)
        report["all_relative_patterns_matched"] || exit(1)
    else
        throw(ArgumentError("Usage: julia --project=. bin/eriec-background-audit.jl examples|measured-witnesses"))
    end
catch err
    println(stderr,"Background audit failed: ",sprint(showerror,err))
    exit(1)
end
